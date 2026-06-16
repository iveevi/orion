export const meta = {
  name: 'prose-forge-academic',
  description: 'Multi-agent pipeline for technical, academic, and pedagogical prose. Draft in diverse academic registers, critique adversarially against inflation/hedging/imprecision, revise until quality gates pass, polish.',
  whenToUse: 'When you need research-paper-grade prose: methods, related-work, tutorial sections, review writeups, explanatory passages. Pass {brief, genre, audience, length, iterations, drafters} as args.',
  phases: [
    { title: 'Draft' },
    { title: 'Refine' },
    { title: 'Polish' },
    { title: 'Judge' },
  ],
}

let parsedArgs = args
if (typeof args === 'string') {
  try { parsedArgs = JSON.parse(args) } catch (e) { parsedArgs = null }
}
log(`args received as ${typeof args}; brief field present: ${!!(parsedArgs && parsedArgs.brief)}`)

const A = parsedArgs || {}
const brief = A.brief || 'Explain why softmax with cross-entropy gives stable gradients, for a reader who knows multivariate calculus but has not implemented a neural network.'
const genre = A.genre || 'pedagogical'
const audience = A.audience || 'a graduate student in the field who has the standard prerequisites but is new to this specific topic'
const targetLength = A.length || 400
const maxIterations = A.iterations || 3
const numDrafters = Math.min(A.drafters || 3, 5)
const criticModel = A.criticModel || null

const BLOCKLIST = {
  phrases: [
    'it is interesting to note that', 'it is worth noting', 'it should be noted',
    'it is well known that', 'it is widely accepted', 'it goes without saying',
    'recent advances have shown', 'recent work has demonstrated',
    'novel approach', 'novel framework', 'novel method', 'state-of-the-art',
    'cutting-edge', 'paradigm shift', 'paradigm-shifting', 'game-changing',
    'comprehensive analysis', 'in-depth', 'thorough investigation',
    'robust framework', 'robust method', 'robust approach',
    'a wide range of', 'a variety of', 'a plethora of', 'a myriad of',
    'plays a key role', 'plays a crucial role', 'plays an important role', 'crucial role',
    'crucial', 'pivotal', 'paramount', 'salient',
    'leverage', 'leveraging', 'utilize', 'utilizing', 'utilization',
    'facilitate', 'facilitates', 'facilitated',
    'in order to', 'so as to', 'with the aim of', 'with the goal of',
    'delve into', 'delves into', 'tease apart', 'unpack', 'lean into',
    'navigate', 'navigating', 'navigated',
    'underscore', 'underscores', 'underscoring',
    'tapestry', 'landscape of', 'ecosystem of',
    'this paper presents', 'this paper proposes', 'we hereby',
    'extensive experiments', 'extensive evaluation',
    'significantly', 'substantially', 'considerably', 'remarkably',
    'highly effective', 'highly efficient', 'highly accurate',
    'a deep understanding', 'a nuanced understanding',
    'shed light on', 'shed new light',
    'in light of', 'in the context of', 'with respect to',
    'on the other hand', 'on the contrary',
    'first and foremost', 'last but not least',
    'in conclusion', 'to conclude', 'in summary', 'to summarize',
    'as we will see', 'as we shall see', 'as discussed above', 'as mentioned earlier',
    'the present work', 'the present study', 'the present paper',
    'in this regard', 'in this respect', 'in this manner',
  ],
  patterns: [
    { name: 'throat-clearing-opener', regex: '^(In this (section|paper|chapter|work)|This (section|paper|chapter|work)|Here(,| we)|We (now |hereby )?(present|propose|introduce|describe))' },
    { name: 'empty-intensifier', regex: '\\b(very|extremely|highly|incredibly|remarkably|exceptionally) (important|useful|effective|interesting|significant|powerful|impressive)' },
    { name: 'hedging-stack', regex: '\\b(may|might|could|possibly|perhaps)\\b[\\w\\s,]{0,30}\\b(may|might|could|possibly|perhaps)\\b' },
    { name: 'nominalized-verb', regex: '\\b(perform|conduct|carry out|make|do|provide|achieve|undertake) (a |an |the )?(\\w+(ation|ment|ysis|ity|ence|ance|ing))\\b' },
    { name: 'as-mentioned', regex: '\\bas (mentioned|discussed|noted|stated|shown|seen) (above|earlier|previously|before)\\b' },
    { name: 'it-is-X-that', regex: '\\bit is (clear|evident|obvious|important|essential|necessary|crucial|interesting|worth|well[- ]known|widely[- ]accepted) (that|to)\\b' },
    { name: 'there-is-construction', regex: '\\bthere (is|are|exists?|exist) (a |an |many |several |various |numerous )\\w+ (that|which) ' },
    { name: 'passive-by-the-method', regex: '\\bwas (performed|conducted|carried out|achieved|obtained|computed|calculated) by (the |our |a )?\\w+ (method|approach|algorithm|technique)' },
    { name: 'doubled-emphasis', regex: '\\b(very|extremely|highly) (significant|important|crucial)ly\\b' },
    { name: 'unjustified-significant', regex: '\\b(a |the )?significant (improvement|gain|increase|decrease|difference|effect|impact|amount|number|portion)' },
  ],
}

const VOICES = [
  {
    name: 'feynman',
    reference: 'Richard Feynman (Lectures on Physics, Six Easy Pieces): explain hard things to smart readers without condescension. Build intuition from the simplest case the reader already knows. Speak directly to the reader ("you can see that..."). Use concrete physical or computational examples. Refuse jargon until you have earned the right to introduce it. Never hedge what is true. The voice is warm but precise.',
  },
  {
    name: 'knuth',
    reference: 'Donald Knuth (The Art of Computer Programming, TeX papers): precise, slightly old-fashioned, every term defined before use. Use small concrete examples that the reader can work through with pencil and paper. Equations integrated into prose, not set apart. Never apologize for difficulty; trust the reader to keep up. Footnotes for asides. The voice is that of a careful teacher who has thought about every word.',
  },
  {
    name: 'olah',
    reference: 'Christopher Olah (distill.pub essays): explanatory prose paired tightly with diagrams (which you cannot draw, so be specific about what visualization would help). Start from a question the reader is actually asking. Build up the explanation layer by layer, each step motivated by the last. Use plain words when plain words suffice. The voice is patient and visual-minded; the reader feels the author thought hard about how to make it easy.',
  },
  {
    name: 'neurips',
    reference: 'Top-venue ML paper (NeurIPS/ICML methods sections): tight, declarative, no decorative prose. Define notation once, use it consistently. State what was done in active voice and past tense when describing experiments, present tense when describing methods. Give the precise condition for every claim. Cite when invoking a non-trivial result. The voice is that of a working researcher writing for working researchers who have limited time.',
  },
  {
    name: 'pinker',
    reference: 'Steven Pinker (The Sense of Style; Words and Rules): "classic style" — write as if showing the reader something in plain view rather than analyzing your own thoughts about it. Concrete subjects performing real actions. Avoid nominalizations ("the implementation of X" → "implementing X" or just "X"). Vary sentence length deliberately. The voice is conversational but exact; never breezy, never stiff.',
  },
]

const SPEC_SCHEMA = {
  type: 'object',
  required: ['claim', 'audience', 'scope_boundaries', 'must_include', 'must_avoid'],
  properties: {
    claim: { type: 'string', description: 'The single load-bearing claim or explanation the passage must deliver, stated in one declarative sentence. If the brief is a multi-part question, this is the unifying through-line.' },
    audience: { type: 'string', description: 'Restated audience assumptions: what they already know, what they do not, what jargon is fair game without definition.' },
    scope_boundaries: { type: 'array', items: { type: 'string' }, description: '2-4 explicit limits — what is NOT being claimed or covered. The passage must not overreach into these.' },
    must_include: { type: 'array', items: { type: 'string' }, description: '3-6 specific things the passage must contain: a derivation step, a numerical example, a definition, a comparison, a counterexample. Be concrete.' },
    must_avoid: { type: 'array', items: { type: 'string' }, description: 'Specific failure modes for this passage given the genre and audience (e.g., "do not assume measure theory", "do not motivate via marketing language").' },
    notation: { type: 'string', description: 'If technical: the variable conventions used (e.g., "x for inputs, y for labels, theta for parameters; bold for vectors, plain for scalars"). Empty if not applicable.' },
  },
}

const CRITIQUE_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['quote', 'diagnosis', 'severity'],
        properties: {
          quote: { type: 'string', description: 'exact text from the draft' },
          diagnosis: { type: 'string', description: 'what is wrong. One sentence. No suggested fix.' },
          severity: { type: 'string', enum: ['fatal', 'high', 'medium', 'low'] },
        },
      },
    },
  },
}

const JUDGE_SCHEMA = {
  type: 'object',
  required: ['winner_index', 'reasoning', 'ranking'],
  properties: {
    winner_index: { type: 'integer' },
    reasoning: { type: 'string', description: 'one paragraph on why this draft, naming specific sentences' },
    ranking: { type: 'array', items: { type: 'integer' }, description: 'all draft indices best to worst' },
  },
}

function blocklistInstruction() {
  return `HARD BLOCKLIST. You may not use any of these words or phrases, in any inflection:\n${BLOCKLIST.phrases.map(p => `- ${p}`).join('\n')}\n\nYou may not produce text matching these patterns:\n${BLOCKLIST.patterns.map(p => `- ${p.name}`).join('\n')}`
}

phase('Draft')
const spec = await agent(
  `You are extracting the working spec for a piece of academic / technical / pedagogical prose.\n\nBRIEF:\n${brief}\n\nGENRE: ${genre} (one of: methods, related-work, tutorial, review, results, discussion, pedagogical, introduction)\nAUDIENCE: ${audience}\nTARGET LENGTH: ~${targetLength} words.\n\nReturn a structured spec.\n\nABSOLUTE RULE: You are NOT a co-author. You do not invent a different topic, subject, or angle. The brief defines what is being explained; you extract the structure that lets a drafter write it well. If the brief specifies a topic, your spec preserves that topic exactly.\n\nThe "claim" field is the single declarative sentence the passage must deliver. If the brief asks a question, the claim is the answer.\n\nThe "must_include" list is the most important field: enumerate the specific things (derivation steps, definitions, examples, comparisons) the passage cannot omit.\n\nThe "scope_boundaries" list bounds the passage — what it must NOT try to cover.`,
  { schema: SPEC_SCHEMA, label: 'spec' }
)

function draftPrompt(voice) {
  return `You are a drafter working in the expository tradition of:\n\n${voice.reference}\n\nWrite the following passage in that register. Do not name the author or imitate biographical content — only the syntactic, lexical, and pedagogical habits.\n\nBRIEF (the passage you are writing — every concrete fact here is binding):\n${brief}\n\nGENRE: ${genre}\nAUDIENCE: ${audience}\n\nSPEC:\n- Central claim (the passage must deliver this): ${spec.claim}\n- Restated audience: ${spec.audience}\n- Scope boundaries (the passage must NOT cover these): ${spec.scope_boundaries.join('; ')}\n- Must include: ${spec.must_include.join('; ')}\n- Must avoid: ${spec.must_avoid.join('; ')}\n${spec.notation ? `- Notation: ${spec.notation}` : ''}\n\nTarget length: ~${targetLength} words. Going under is fine if the passage is complete.\n\nRULES:\n0. The topic is the topic in the brief. You are not free to substitute a related topic you find more interesting.\n1. Concrete subjects, active verbs. Subjects should be people, things, or named quantities — not abstract nominalizations.\n2. Define each technical term the first time it appears. Do not redefine it.\n3. State the claim, then the support. Do not bury the load-bearing sentence in the middle of a paragraph.\n4. Every sentence advances the argument. None restates the prior sentence in different words.\n5. Hedge precisely or not at all. Do not stack hedges ("it may possibly be that..."). If you are certain, say so.\n6. Use the simplest construction that is correct. Prefer "to" over "in order to", "use" over "utilize", "by" over "by means of".\n7. Vary sentence length deliberately, but do not write singsong rhythm. Two short sentences in a row should land as emphasis, not as inability to construct longer ones.\n8. No throat-clearing openings ("In this section we will discuss..."). Start with the substance.\n9. Mathematics is written in LaTeX, not ASCII. Inline math uses single-dollar delimiters: $p_i = \\exp(z_i) / \\sum_j \\exp(z_j)$. Display equations sit on their own paragraph between double dollars:\\n\\n   $$\\frac{\\partial L}{\\partial z_i} = p_i - y_i.$$\\n\\n   Greek letters: \\\\alpha, \\\\beta, \\\\delta, \\\\theta, \\\\epsilon, \\\\sigma, \\\\Sigma, \\\\Omega. Subscripts $z_i$, superscripts $x^2$, partial derivatives $\\\\partial L / \\\\partial z$, sums $\\\\sum_{j=1}^{K}$, norms $\\\\lVert x \\\\rVert$, sets $\\\\{x : x > 0\\\\}$. Use $\\\\mathbf{x}$ for vectors when the scalar/vector distinction needs marking. ASCII forms like p_i, delta_ij, sum_j exp(z_j), or 10^-2 are forbidden — write $p_i$, $\\\\delta_{ij}$, $\\\\sum_j \\\\exp(z_j)$, $10^{-2}$.\\n10. A standalone display equation must be commented on by surrounding prose; an inline equation must read aloud as a clause.\\n11. The closing sentence does the work of closing — it does not restate the opening or hand-wave at "future directions".\n\n${blocklistInstruction()}\n\nReturn ONLY the prose. No title, no commentary, no preamble.`
}

const selectedVoices = VOICES.slice(0, numDrafters)
const drafts = (await parallel(
  selectedVoices.map((v, i) => () =>
    agent(draftPrompt(v), { label: `draft:${v.name}`, phase: 'Draft' })
  )
)).map((text, i) => ({ text, voice: selectedVoices[i].name, index: i })).filter(d => d.text)

if (!drafts.length) {
  throw new Error('All drafters failed.')
}

const CRITICS = [
  {
    key: 'ai-tics',
    prompt: (draft, ctx) => `You are detecting LLM-generated academic prose. Default to GUILTY. For each suspect passage, quote it, name the tic, and rate severity. Do not propose fixes. Do not balance praise with criticism.\n\nSpecific tics to hunt:\n- Throat-clearing openers ("In this section we...", "This paper presents...")\n- Empty intensifiers ("very important", "highly effective")\n- Hedging filler ("It is interesting to note that", "It is worth mentioning")\n- Nominalized verbs ("perform an analysis" instead of "analyze")\n- Buzzwords without justification ("novel", "state-of-the-art", "robust")\n- Vague-bold openers ("Recent advances have shown that...")\n- "Significantly" used in a non-statistical sense\n- "Leverage" / "utilize" / "facilitate" where simpler verbs work\n- Passive voice used to dodge attribution ("it has been observed that")\n- Decorative connectives that add no logic ("Furthermore", "Moreover", "Additionally" when the sequence is already clear)\n- "As discussed above" / "As mentioned earlier" pointing at trivial recall\n- Sentence-final "respectively" used as glue rather than reference\n\nDRAFT:\n${draft}\n\nReturn findings. If zero tics, return empty findings array.`,
  },
  {
    key: 'precision',
    prompt: (draft, ctx) => `Flag every vague claim, undefined term, hand-wave, or imprecise quantifier in this draft. Academic prose earns trust by being specific.\n\nLook for:\n- Quantifiers without referents ("many studies", "several methods", "a wide range of")\n- Comparative claims without a baseline ("better", "faster", "more accurate" — compared to what?)\n- Undefined technical terms used before definition\n- "Approximately" / "roughly" / "essentially" without a number\n- Claims that could be true or false with no possible test\n- Pronouns whose antecedents are ambiguous\n- Sentences whose meaning changes depending on how you parse a relative clause\n\nFor each, quote the offending text. Severity reflects how much the imprecision weakens the passage.\n\nDRAFT:\n${draft}`,
  },
  {
    key: 'nominalization',
    prompt: (draft, ctx) => `Find every nominalization (verb hidden inside a noun) and every passive construction that obscures the agent. Quote each. Severity reflects how much the construction blurs who or what is doing what.\n\nExamples:\n- "The implementation of the algorithm" → the verb "implement" is the action\n- "An analysis was performed" → who analyzed?\n- "The application of this technique" → "applying this technique"\n- "There is a tendency for X to Y" → "X tends to Y"\n\nDo not flag passive voice that is correct (e.g., when the agent is unknown or unimportant: "the sample was collected in 2019" is fine if the collector is irrelevant). Flag passive voice that is used to evade agency or to add formality without precision.\n\nDRAFT:\n${draft}`,
  },
  {
    key: 'claim-evidence',
    prompt: (draft, ctx) => `Identify every load-bearing claim in this passage and judge whether it is supported. Load-bearing means the rest of the passage depends on the claim being true. Support means: a derivation, a citation, a definition, a worked example, or a logical entailment from a prior statement in the passage.\n\nFor each unsupported load-bearing claim, quote it and diagnose what kind of support is missing (citation? proof step? example? definition?). Severity is highest where the unsupported claim is doing the most work.\n\nDo not flag claims that are clearly stipulated, intuitively obvious to the stated audience, or supported earlier in the passage.\n\nCENTRAL CLAIM (the passage must deliver this): ${spec.claim}\nAUDIENCE ASSUMPTIONS: ${spec.audience}\n\nDRAFT:\n${draft}`,
  },
  {
    key: 'structure-flow',
    prompt: (draft, ctx) => `Audit the logical flow of this passage. Flag:\n- Paragraphs that do not have a clear single point\n- Adjacent sentences whose logical connection is unclear (would the reader have to backtrack?)\n- Order-of-introduction problems (X is used before X is defined or motivated)\n- Buried lede: a load-bearing sentence hidden mid-paragraph when it should open it\n- Conclusions that don't follow from what came before\n- "Signposting" that is decorative rather than load-bearing (a "Furthermore" that connects two unrelated points)\n\nQuote the offending stretch. Diagnose the structural break.\n\nDRAFT:\n${draft}`,
  },
  {
    key: 'audience-fit',
    prompt: (draft, ctx) => `Judge whether this passage talks at the right level for the stated audience.\n\nAUDIENCE: ${spec.audience || ctx.audience}\n\nFlag:\n- Definitions of terms the audience already knows (talking down)\n- Use of terms the audience does not know without definition (talking over)\n- Tone that condescends ("Don't worry, this is easy", "Simply...")\n- Tone that gatekeeps (assuming the reader will recognize an obscure reference without citation)\n- Asides that serve the author's ego rather than the reader's understanding\n\nQuote offending sentences.\n\nDRAFT:\n${draft}`,
  },
  {
    key: 'hedging-balance',
    prompt: (draft, ctx) => `Audit the hedging in this passage. Both extremes are failures.\n\nOverhedging: stacked qualifiers ("it may possibly be that..."), hedges on claims that are not actually uncertain, "we believe / we think" applied to known results, "to some extent" / "in some sense" as filler.\n\nUnderhedging: stating contested claims as fact, omitting necessary scope ("X is true" when "X is true under assumption Y" is the actual claim), absolutes ("always", "never", "in all cases") without justification.\n\nQuote each offense and label it (overhedge or underhedge). Severity is highest where the calibration error misleads the reader about what is known.\n\nDRAFT:\n${draft}`,
  },
  {
    key: 'brief-fidelity',
    prompt: (draft, ctx) => `Check whether this draft is actually answering the brief. The brief specified a topic, a question, or an explanation target. The draft must address THAT, not an adjacent topic the drafter found more tractable.\n\nORIGINAL BRIEF:\n${brief}\n\nCENTRAL CLAIM (extracted from brief): ${spec.claim}\n\nDRAFT:\n${draft}\n\nFlag any concrete drift: the draft answers a different question, omits the specific subject of the brief, or covers a generalization where the brief asked for a specific case (or vice versa). Severity 'fatal' for any deviation that changes the subject. Quote the offending text. If the draft is on-topic, return empty findings.`,
  },
  {
    key: 'math-notation',
    prompt: (draft, ctx) => `Check that mathematics in this passage is written in LaTeX, not ASCII. Flag any of the following:\n\n- Unwrapped variable subscripts/superscripts: "p_i" instead of $p_i$, "z^2" instead of $z^2$, "x_{ij}" outside math mode\n- ASCII Greek: "alpha", "delta_ij", "epsilon", "theta", "sigma" used as math symbols outside $...$\n- ASCII operators: "sum_j", "prod_i", "int_0^1", "partial L / partial z" outside math mode\n- ASCII exp / log / sin without backslash inside math mode: $exp(z_i)$ should be $\\exp(z_i)$\n- Display equations not in $$...$$ blocks\n- Single-line equations indented as code blocks instead of using $$...$$\n- Numerical values with caret exponents outside math: "10^-2" should be $10^{-2}$\n- Kronecker delta written as "delta_ij" instead of $\\delta_{ij}$\n- Approximate / order-of-magnitude notation written textually when it should be math: "approx 0.99" instead of $\\approx 0.99$\n\nQuote each offending substring. Diagnose what LaTeX form it should take. Severity 'high' for any unwrapped math; 'medium' for inconsistent style within a passage. If math notation is clean, return empty findings.\n\nDRAFT:\n${draft}`,
  },
]

function regexCritique(draft) {
  const findings = []
  for (const p of BLOCKLIST.phrases) {
    const re = new RegExp('\\b' + p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b', 'gi')
    let m
    while ((m = re.exec(draft)) !== null) {
      findings.push({ quote: m[0], diagnosis: `blocklisted phrase: "${p}"`, severity: 'high' })
    }
  }
  for (const p of BLOCKLIST.patterns) {
    const re = new RegExp(p.regex, 'gi')
    let m
    while ((m = re.exec(draft)) !== null) {
      findings.push({ quote: m[0], diagnosis: `pattern: ${p.name}`, severity: 'high' })
    }
  }
  return findings
}

async function refineDraft(draft, draftIdx) {
  let current = draft.text
  let history = []
  const voiceRef = selectedVoices.find(v => v.name === draft.voice).reference
  const ctx = { voice: draft.voice, voiceReference: voiceRef, audience }
  const criticOpts = criticModel ? { schema: CRITIQUE_SCHEMA, model: criticModel } : { schema: CRITIQUE_SCHEMA }
  for (let iter = 0; iter < maxIterations; iter++) {
    const critiques = await parallel(
      CRITICS.map(c => () =>
        agent(c.prompt(current, ctx), {
          ...criticOpts,
          label: `${c.key}:d${draftIdx}:i${iter}`,
          phase: 'Refine',
        })
      )
    )
    const regex = regexCritique(current)
    const all = []
    critiques.forEach((c, ci) => {
      if (c && c.findings) {
        c.findings.forEach(f => all.push({ critic: CRITICS[ci].key, ...f }))
      }
    })
    regex.forEach(f => all.push({ critic: 'regex', ...f }))

    const fatal = all.filter(f => f.severity === 'fatal' || f.severity === 'high').length
    log(`draft ${draftIdx} (${draft.voice}) iter ${iter}: ${all.length} findings (${fatal} severe)`)

    if (all.length === 0 || (iter > 0 && fatal === 0 && all.length < 3)) break
    if (iter === maxIterations - 1) break

    const critiqueText = all
      .slice(0, 30)
      .map(f => `[${f.critic} | ${f.severity}] "${f.quote}" — ${f.diagnosis}`)
      .join('\n')

    current = await agent(
      `You are revising an academic / technical passage based on adversarial critique. You may NOT smooth, soften, or hand-wave around the flagged passages. You must address each finding by cutting, rewriting, or substantively replacing the flagged text.\n\nDO NOT add inflation, decorative connectives, or throat-clearing while fixing. Cuts are preferable to rewrites. The passage may shrink.\n\nMATHEMATICS: preserve and use LaTeX. Inline math in $...$, display equations in $$...$$ on their own paragraphs. If the current draft contains ASCII math (p_i, delta_ij, sum_j, 10^-2), convert it to LaTeX as part of the revision.\n\nREGISTER (preserve this):\n${voiceRef}\n\nBRIEF (still binding):\n${brief}\n\nCENTRAL CLAIM (still the through-line): ${spec.claim}\nAUDIENCE: ${spec.audience}\nMUST INCLUDE: ${spec.must_include.join('; ')}\nMUST AVOID: ${spec.must_avoid.join('; ')}\n\n${blocklistInstruction()}\n\nCRITIQUES (each quote must be addressed):\n${critiqueText}\n\nCURRENT DRAFT:\n${current}\n\nReturn ONLY the revised passage. No commentary.`,
      { label: `revise:d${draftIdx}:i${iter}`, phase: 'Refine' }
    )
    if (!current) break
    history.push({ iter, findings: all.length, fatal })
  }
  return { text: current, voice: draft.voice, index: draftIdx, history }
}

const refined = (await parallel(
  drafts.map(d => () => refineDraft(d, d.index))
)).filter(r => r && r.text)

phase('Polish')
const polished = await parallel(
  refined.map(r => () =>
    agent(
      `You are doing a final line-edit pass on academic prose. ONLY word-level changes, comma surgery, and deletions. NO structural changes. NO new sentences except to replace a deletion with something tighter.\n\nYou are removing the residue of revision: any transitional filler, any softening word, any phrase that sounds like an editor put it there.\n\nSpecifically:\n- Cut "Furthermore" / "Moreover" / "Additionally" when the next sentence already follows logically\n- Replace "in order to" with "to", "utilize" with "use", "leverage" with "use" or "exploit"\n- Cut "really", "very", "quite", "rather" as adverbs\n- Cut "It is worth noting that" / "Importantly" / "Note that" preambles — just state the point\n- Replace "perform an X" with "X" where X is a verb in nominal form\n- Replace passive constructions with active ones unless the agent is genuinely unknown or unimportant\n\nMATHEMATICS: preserve LaTeX exactly. Do not "fix" $...$ to (...) or unwrap display equations. Do not normalize \\\\sum to sum or \\\\delta to delta. If you find any residual ASCII math (variable_subscript, "sum_j", "10^-2"), convert it to LaTeX.\n\nIf a sentence is already tight, leave it untouched.\n\n${blocklistInstruction()}\n\nDRAFT:\n${r.text}\n\nReturn ONLY the polished prose.`,
      { label: `polish:${r.voice}`, phase: 'Polish' }
    ).then(text => ({ ...r, text: text || r.text }))
  )
)

const finalists = polished.filter(p => p && p.text)

phase('Judge')
const numbered = finalists.map((f, i) => `=== DRAFT ${i} (register: ${f.voice}) ===\n${f.text}`).join('\n\n')
const verdict = await agent(
  `You are a senior editor at a top-venue research journal choosing between ${finalists.length} drafts of the same brief. Pick the draft that does the most work per word and that a working researcher in the field would actually want to read.\n\nCriteria, in order:\n1. Brief fidelity — does it answer the actual question?\n2. Precision — every claim load-bearing and supported\n3. Concision — high information per sentence; no filler, no inflation\n4. Audience fit — neither talks down nor talks over the stated audience\n5. Voice consistency — one register held throughout\n6. The presence of at least one sentence that makes the underlying idea clearer than the reader expected\n\nName specific sentences in your reasoning. Do not award points for "well-structured" or "comprehensive" prose — those are failure modes when they substitute for substance.\n\nBRIEF:\n${brief}\n\nDRAFTS:\n${numbered}`,
  { schema: JUDGE_SCHEMA, label: 'judge', phase: 'Judge' }
)

const winner = finalists[verdict.winner_index] || finalists[0]

log(`output tokens spent (this run): ${budget.spent()}`)

function buildMarkdown() {
  const lines = []
  lines.push(`# prose-forge-academic result`)
  lines.push('')
  lines.push(`**Brief.** ${brief}`)
  lines.push('')
  lines.push(`**Genre.** ${genre}  `)
  lines.push(`**Audience.** ${audience}  `)
  lines.push(`**Target length.** ${targetLength} words  `)
  lines.push(`**Iterations.** ${maxIterations}  `)
  lines.push(`**Drafters.** ${numDrafters}  `)
  lines.push(`**Critic model.** ${criticModel || 'inherited'}  `)
  lines.push(`**Winning register.** ${winner.voice}  `)
  lines.push(`**Output tokens.** ${budget.spent()}`)
  lines.push('')
  lines.push('---')
  lines.push('')
  lines.push('## Winning draft')
  lines.push('')
  lines.push(winner.text)
  lines.push('')
  lines.push('---')
  lines.push('')
  lines.push("## Judge's reasoning")
  lines.push('')
  lines.push(verdict.reasoning)
  lines.push('')
  lines.push('---')
  lines.push('')
  lines.push('## Spec (extracted from brief)')
  lines.push('')
  lines.push(`**Central claim.** ${spec.claim}`)
  lines.push('')
  lines.push(`**Audience (restated).** ${spec.audience}`)
  lines.push('')
  lines.push('**Must include.**')
  lines.push('')
  for (const m of spec.must_include || []) lines.push(`- ${m}`)
  lines.push('')
  lines.push('**Scope boundaries.**')
  lines.push('')
  for (const m of spec.scope_boundaries || []) lines.push(`- ${m}`)
  lines.push('')
  lines.push('**Must avoid.**')
  lines.push('')
  for (const m of spec.must_avoid || []) lines.push(`- ${m}`)
  lines.push('')
  if (spec.notation) {
    lines.push(`**Notation.** ${spec.notation}`)
    lines.push('')
  }
  lines.push('---')
  lines.push('')
  lines.push('## Alternates (ranked)')
  lines.push('')
  const rank = verdict.ranking && verdict.ranking.length ? verdict.ranking : finalists.map((_, i) => i)
  let r = 1
  for (const idx of rank) {
    const f = finalists[idx]
    if (!f) continue
    lines.push(`### #${r} — register: ${f.voice}`)
    lines.push('')
    lines.push(f.text)
    lines.push('')
    r++
  }
  return lines.join('\n')
}

const markdown = buildMarkdown()

return {
  prose: winner.text,
  winning_register: winner.voice,
  reasoning: verdict.reasoning,
  spec,
  alternates: finalists.map(f => ({ voice: f.voice, text: f.text })),
  ranking: verdict.ranking,
  output_tokens: budget.spent(),
  markdown,
}
