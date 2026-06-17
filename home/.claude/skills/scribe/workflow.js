export const meta = {
  name: 'scribe',
  description: 'Hybrid pipeline for technical/academic prose and reports, grounded in a supplied reference set. Spec -> parallel drafts in distinct academic voices -> one adversarial critic+revise round -> polish -> judge. Drafters cite from the references they are given.',
  whenToUse: 'When you need research-paper-grade prose grounded in real citations: methods, related-work, reports, tutorial sections, explanatory passages. The orchestrator gathers references via the paper skill first, then passes {brief, genre, audience, length, references} as args.',
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

const A = parsedArgs || {}
const brief = A.brief || 'Explain why softmax with cross-entropy gives stable gradients, for a reader who knows multivariate calculus but has not implemented a neural network.'
const genre = A.genre || 'pedagogical'
const audience = A.audience || 'a graduate student in the field who has the standard prerequisites but is new to this specific topic'
const targetLength = A.length || 400
const maxIterations = Math.max(1, A.iterations || 1)
const numDrafters = Math.min(Math.max(1, A.drafters || 2), 5)
const criticModel = A.criticModel || null
const references = Array.isArray(A.references) ? A.references : []

log(`brief present: ${!!A.brief}; references supplied: ${references.length}; drafters: ${numDrafters}; iterations: ${maxIterations}`)

function referenceBlock() {
  if (!references.length) {
    return 'NO REFERENCES SUPPLIED. Do not invent citations. Do not write \\cite{...} or [@key] for sources you were not given. If a claim needs a citation you do not have, state the claim plainly without a fabricated reference.'
  }
  const lines = references.map(r => {
    const key = r.citekey || r.id || 'unknown'
    const title = r.title || '(untitled)'
    const authors = r.authors ? ` — ${r.authors}` : ''
    const year = r.year ? ` (${r.year})` : ''
    const claims = r.claims || r.digest || r.summary || ''
    return `- [@${key}] ${title}${authors}${year}\n    ${claims}`.trim()
  })
  return `REFERENCE SET (cite ONLY from these; use the bracket-key form [@citekey] inline). These are real papers already in the user's ~/papers collection and references.bib:\n\n${lines.join('\n')}\n\nCITATION RULES:\n- Cite a reference whenever you state a non-trivial result, definition, or empirical claim that comes from it.\n- Use the exact [@citekey] given above. Never invent a citekey.\n- Do not pad: cite where a claim genuinely rests on a source, not decoratively.\n- It is fine to leave a sentence uncited if it is your own reasoning, a definition, or common knowledge for the audience.`
}

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
    { name: 'throat-clearing-opener', regex: '^(In this (section|paper|chapter|work|report)|This (section|paper|chapter|work|report)|Here(,| we)|We (now |hereby )?(present|propose|introduce|describe))' },
    { name: 'empty-intensifier', regex: '\\b(very|extremely|highly|incredibly|remarkably|exceptionally) (important|useful|effective|interesting|significant|powerful|impressive)' },
    { name: 'hedging-stack', regex: '\\b(may|might|could|possibly|perhaps)\\b[\\w\\s,]{0,30}\\b(may|might|could|possibly|perhaps)\\b' },
    { name: 'nominalized-verb', regex: '\\b(perform|conduct|carry out|make|do|provide|achieve|undertake) (a |an |the )?(\\w+(ation|ment|ysis|ity|ence|ance|ing))\\b' },
    { name: 'as-mentioned', regex: '\\bas (mentioned|discussed|noted|stated|shown|seen) (above|earlier|previously|before)\\b' },
    { name: 'it-is-X-that', regex: '\\bit is (clear|evident|obvious|important|essential|necessary|crucial|interesting|worth|well[- ]known|widely[- ]accepted) (that|to)\\b' },
    { name: 'there-is-construction', regex: '\\bthere (is|are|exists?|exist) (a |an |many |several |various |numerous )\\w+ (that|which) ' },
    { name: 'passive-by-the-method', regex: '\\bwas (performed|conducted|carried out|achieved|obtained|computed|calculated) by (the |our |a )?\\w+ (method|approach|algorithm|technique)' },
    { name: 'unjustified-significant', regex: '\\b(a |the )?significant (improvement|gain|increase|decrease|difference|effect|impact|amount|number|portion)' },
  ],
}

const VOICES = [
  {
    name: 'neurips',
    reference: 'Top-venue ML/systems paper (NeurIPS/ICML/SOSP methods and related-work sections): tight, declarative, no decorative prose. Define notation once, use it consistently. State what was done in active voice and past tense for experiments, present tense for methods. Give the precise condition for every claim. Cite when invoking a non-trivial result. The voice is a working researcher writing for working researchers with limited time.',
  },
  {
    name: 'pinker',
    reference: 'Steven Pinker (The Sense of Style): "classic style" — write as if showing the reader something in plain view rather than analyzing your own thoughts about it. Concrete subjects performing real actions. Avoid nominalizations ("the implementation of X" -> "implementing X"). Vary sentence length deliberately. Conversational but exact; never breezy, never stiff.',
  },
  {
    name: 'feynman',
    reference: 'Richard Feynman (Lectures on Physics): explain hard things to smart readers without condescension. Build intuition from the simplest case the reader already knows. Speak directly to the reader ("you can see that..."). Use concrete examples. Refuse jargon until you have earned the right to introduce it. Never hedge what is true. Warm but precise.',
  },
  {
    name: 'knuth',
    reference: 'Donald Knuth (TAOCP, TeX papers): precise, every term defined before use. Small concrete examples the reader can work through by hand. Equations integrated into prose. Never apologize for difficulty; trust the reader. The voice of a careful teacher who has thought about every word.',
  },
  {
    name: 'olah',
    reference: 'Christopher Olah (distill.pub): explanatory prose that names the visualization that would help (you cannot draw it, so describe it precisely). Start from a question the reader is actually asking. Build the explanation layer by layer, each step motivated by the last. Plain words when plain words suffice.',
  },
]

const SPEC_SCHEMA = {
  type: 'object',
  required: ['claim', 'audience', 'scope_boundaries', 'must_include', 'must_avoid'],
  properties: {
    claim: { type: 'string', description: 'The single load-bearing claim or explanation the passage must deliver, in one declarative sentence.' },
    audience: { type: 'string', description: 'Restated audience assumptions: what they know, what they do not, what jargon is fair game.' },
    scope_boundaries: { type: 'array', items: { type: 'string' }, description: '2-4 explicit limits — what is NOT being claimed or covered.' },
    must_include: { type: 'array', items: { type: 'string' }, description: '3-6 specific things the passage must contain: a derivation step, a numerical example, a definition, a comparison, a cited result.' },
    must_avoid: { type: 'array', items: { type: 'string' }, description: 'Specific failure modes for this passage given the genre and audience.' },
    notation: { type: 'string', description: 'If technical: the variable conventions used. Empty if not applicable.' },
    citations_expected: { type: 'array', items: { type: 'string' }, description: 'Which of the supplied reference citekeys this passage should most likely cite, given the claim. Empty if no references were supplied.' },
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

const mathRules = `Mathematics is written in LaTeX, not ASCII. Inline math uses single-dollar delimiters: $p_i = \\exp(z_i) / \\sum_j \\exp(z_j)$. Display equations sit on their own paragraph between double dollars. Greek: \\alpha, \\beta, \\theta, \\sigma, \\Sigma. ASCII forms like p_i, delta_ij, sum_j exp(z_j), or 10^-2 are forbidden — write $p_i$, $\\delta_{ij}$, $\\sum_j \\exp(z_j)$, $10^{-2}$.`

phase('Draft')
const spec = await agent(
  `You are extracting the working spec for a piece of academic / technical prose or a report section.\n\nBRIEF:\n${brief}\n\nGENRE: ${genre} (methods, related-work, tutorial, review, results, discussion, report, pedagogical, introduction)\nAUDIENCE: ${audience}\nTARGET LENGTH: ~${targetLength} words.\n\n${referenceBlock()}\n\nReturn a structured spec.\n\nABSOLUTE RULE: You are NOT a co-author. You do not invent a different topic or angle. The brief defines what is being written; you extract the structure that lets a drafter write it well.\n\nThe "claim" field is the single declarative sentence the passage must deliver. The "must_include" list enumerates the specific things the passage cannot omit. The "citations_expected" field maps the claim onto the supplied reference citekeys.`,
  { schema: SPEC_SCHEMA, label: 'spec' }
)

function draftPrompt(voice) {
  return `You are a drafter working in the expository tradition of:\n\n${voice.reference}\n\nWrite the following passage in that register. Do not name the author or imitate biographical content — only the syntactic, lexical, and pedagogical habits.\n\nBRIEF (every concrete fact here is binding):\n${brief}\n\nGENRE: ${genre}\nAUDIENCE: ${audience}\n\nSPEC:\n- Central claim (must deliver this): ${spec.claim}\n- Restated audience: ${spec.audience}\n- Scope boundaries (must NOT cover): ${spec.scope_boundaries.join('; ')}\n- Must include: ${spec.must_include.join('; ')}\n- Must avoid: ${spec.must_avoid.join('; ')}\n${spec.notation ? `- Notation: ${spec.notation}` : ''}\n${spec.citations_expected && spec.citations_expected.length ? `- Likely citations: ${spec.citations_expected.map(c => `[@${c}]`).join(', ')}` : ''}\n\n${referenceBlock()}\n\nTarget length: ~${targetLength} words. Going under is fine if the passage is complete.\n\nRULES:\n0. The topic is the topic in the brief. You may not substitute a related topic.\n1. Concrete subjects, active verbs. Subjects are people, things, or named quantities — not abstract nominalizations.\n2. Define each technical term the first time it appears. Do not redefine it.\n3. State the claim, then the support. Do not bury the load-bearing sentence mid-paragraph.\n4. Every sentence advances the argument. None restates the prior sentence.\n5. Hedge precisely or not at all. If you are certain, say so.\n6. Use the simplest construction that is correct.\n7. Vary sentence length deliberately; avoid singsong rhythm.\n8. No throat-clearing openings. Start with the substance.\n9. ${mathRules}\n10. A standalone display equation must be commented on by surrounding prose; an inline equation must read aloud as a clause.\n11. The closing sentence does the work of closing — it does not restate the opening or hand-wave at "future directions".\n\n${blocklistInstruction()}\n\nReturn ONLY the prose (with [@citekey] citations inline where warranted). No title, no commentary, no preamble, no bibliography.`
}

const selectedVoices = VOICES.slice(0, numDrafters)
const drafts = (await parallel(
  selectedVoices.map((v) => () =>
    agent(draftPrompt(v), { label: `draft:${v.name}`, phase: 'Draft' })
  )
)).map((text, i) => ({ text, voice: selectedVoices[i].name, index: i })).filter(d => d.text)

if (!drafts.length) {
  throw new Error('All drafters failed.')
}

const validKeys = references.map(r => r.citekey || r.id).filter(Boolean)

const CRITICS = [
  {
    key: 'style',
    prompt: (draft) => `You are detecting LLM-generated academic prose and imprecision. Default to GUILTY. For each suspect passage, quote it, name the fault, rate severity. Do not propose fixes. Do not balance praise with criticism.\n\nHunt for:\n- Throat-clearing openers; empty intensifiers; hedging filler\n- Nominalized verbs ("perform an analysis" -> "analyze")\n- Buzzwords without justification ("novel", "state-of-the-art", "robust")\n- "Significantly" used in a non-statistical sense; "leverage"/"utilize"/"facilitate"\n- Decorative connectives ("Furthermore", "Moreover") where the sequence is already clear\n- Vague quantifiers ("many studies", "a wide range of"); comparatives without a baseline\n- Undefined terms used before definition; ambiguous pronoun antecedents\n- ASCII math that should be LaTeX (p_i, sum_j, delta_ij, 10^-2, bare exp/log)\n\nDRAFT:\n${draft}\n\nReturn findings. If clean, return empty findings array.`,
  },
  {
    key: 'substance',
    prompt: (draft) => `Audit substance, structure, and citation fidelity. Quote each offense; diagnose in one sentence; rate severity.\n\nClaim/evidence:\n- Every load-bearing claim must be supported (derivation, citation, definition, worked example, or entailment). Flag unsupported ones; severity highest where the unsupported claim does the most work.\n\nStructure/flow:\n- Paragraphs without a single clear point; adjacent sentences whose logical link is unclear; X used before X is defined; buried lede; conclusions that don't follow.\n\nBrief fidelity:\n- Does the draft answer THIS brief, not an adjacent topic? Severity 'fatal' for any subject drift.\nORIGINAL BRIEF: ${brief}\nCENTRAL CLAIM: ${spec.claim}\n\nCitation fidelity (critical):\n- The ONLY valid citekeys are: ${validKeys.length ? validKeys.map(k => `[@${k}]`).join(', ') : '(none — any [@...] or \\cite{...} is fabricated and is severity fatal)'}.\n- Flag every citation whose key is NOT in that list as severity 'fatal' (fabricated reference).\n- Flag load-bearing empirical or prior-result claims that SHOULD cite one of the available references but don't, as severity 'high'.\n- Flag decorative/padding citations (cited where the sentence is the author's own reasoning) as severity 'low'.\n\nDRAFT:\n${draft}`,
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
  const voiceRef = selectedVoices.find(v => v.name === draft.voice).reference
  const criticOpts = criticModel ? { schema: CRITIQUE_SCHEMA, model: criticModel } : { schema: CRITIQUE_SCHEMA }
  for (let iter = 0; iter < maxIterations; iter++) {
    const critiques = await parallel(
      CRITICS.map(c => () =>
        agent(c.prompt(current), {
          ...criticOpts,
          label: `${c.key}:d${draftIdx}:i${iter}`,
          phase: 'Refine',
        })
      )
    )
    const all = []
    critiques.forEach((c, ci) => {
      if (c && c.findings) c.findings.forEach(f => all.push({ critic: CRITICS[ci].key, ...f }))
    })
    regexCritique(current).forEach(f => all.push({ critic: 'regex', ...f }))

    const severe = all.filter(f => f.severity === 'fatal' || f.severity === 'high').length
    log(`draft ${draftIdx} (${draft.voice}) iter ${iter}: ${all.length} findings (${severe} severe)`)

    if (all.length === 0) break
    if (iter === maxIterations - 1) break

    const critiqueText = all
      .slice(0, 30)
      .map(f => `[${f.critic} | ${f.severity}] "${f.quote}" — ${f.diagnosis}`)
      .join('\n')

    current = await agent(
      `You are revising academic / technical prose based on adversarial critique. You may NOT smooth, soften, or hand-wave around the flagged passages. Address each finding by cutting, rewriting, or substantively replacing the flagged text. Cuts are preferable to rewrites; the passage may shrink.\n\nCITATIONS: fix every fabricated citekey — the ONLY valid keys are ${validKeys.length ? validKeys.map(k => `[@${k}]`).join(', ') : '(none; remove all citations)'}. Add a cited reference where a load-bearing claim was flagged as needing one. Remove decorative citations.\n\n${mathRules}\n\nREGISTER (preserve this):\n${voiceRef}\n\nBRIEF (still binding):\n${brief}\nCENTRAL CLAIM: ${spec.claim}\nAUDIENCE: ${spec.audience}\nMUST INCLUDE: ${spec.must_include.join('; ')}\nMUST AVOID: ${spec.must_avoid.join('; ')}\n\n${blocklistInstruction()}\n\nCRITIQUES (each quote must be addressed):\n${critiqueText}\n\nCURRENT DRAFT:\n${current}\n\nReturn ONLY the revised passage. No commentary.`,
      { label: `revise:d${draftIdx}:i${iter}`, phase: 'Refine' }
    )
    if (!current) { current = draft.text; break }
  }
  return { text: current, voice: draft.voice, index: draftIdx }
}

const refined = (await parallel(
  drafts.map(d => () => refineDraft(d, d.index))
)).filter(r => r && r.text)

phase('Polish')
const polished = await parallel(
  refined.map(r => () =>
    agent(
      `You are doing a final line-edit pass on academic prose. ONLY word-level changes, comma surgery, and deletions. NO structural changes. NO new sentences except to replace a deletion with something tighter.\n\nRemove the residue of revision: transitional filler, softening words, editor-sounding phrases. Cut "Furthermore"/"Moreover"/"Additionally" when the next sentence already follows. Replace "in order to"->"to", "utilize"/"leverage"->"use". Cut "really"/"very"/"quite"/"rather". Cut "It is worth noting that"/"Importantly"/"Note that" preambles.\n\nLEAVE ALL [@citekey] CITATIONS EXACTLY AS THEY ARE. ${mathRules} Do not unwrap LaTeX.\n\nIf a sentence is already tight, leave it untouched.\n\n${blocklistInstruction()}\n\nDRAFT:\n${r.text}\n\nReturn ONLY the polished prose.`,
      { label: `polish:${r.voice}`, phase: 'Polish' }
    ).then(text => ({ ...r, text: text || r.text }))
  )
)

const finalists = polished.filter(p => p && p.text)

phase('Judge')
const numbered = finalists.map((f, i) => `=== DRAFT ${i} (register: ${f.voice}) ===\n${f.text}`).join('\n\n')
const verdict = finalists.length === 1
  ? { winner_index: 0, reasoning: 'Single drafter; no comparison.', ranking: [0] }
  : await agent(
      `You are a senior editor at a top-venue research journal choosing between ${finalists.length} drafts of the same brief. Pick the draft that does the most work per word and that a working researcher would actually want to read.\n\nCriteria, in order:\n1. Brief fidelity — answers the actual question\n2. Precision — every claim load-bearing and supported\n3. Citation quality — claims rest on the right references, no fabricated keys, no padding\n4. Concision — high information per sentence; no filler\n5. Audience fit — neither talks down nor talks over\n6. Voice consistency — one register throughout\n7. At least one sentence that makes the idea clearer than the reader expected\n\nName specific sentences in your reasoning. Do not reward "well-structured" or "comprehensive" prose when it substitutes for substance.\n\nBRIEF:\n${brief}\n\nDRAFTS:\n${numbered}`,
      { schema: JUDGE_SCHEMA, label: 'judge', phase: 'Judge' }
    )

const winner = finalists[verdict.winner_index] || finalists[0]
log(`output tokens spent (this run): ${budget.spent()}`)

function buildMarkdown() {
  const lines = []
  lines.push(`# scribe result`)
  lines.push('')
  lines.push(`**Brief.** ${brief}`)
  lines.push('')
  lines.push(`**Genre.** ${genre}  `)
  lines.push(`**Audience.** ${audience}  `)
  lines.push(`**Target length.** ${targetLength} words  `)
  lines.push(`**Drafters.** ${numDrafters}  `)
  lines.push(`**Iterations.** ${maxIterations}  `)
  lines.push(`**Winning register.** ${winner.voice}  `)
  lines.push(`**References supplied.** ${references.length}  `)
  lines.push(`**Output tokens.** ${budget.spent()}`)
  lines.push('')
  if (references.length) {
    lines.push('**Reference set.**')
    lines.push('')
    for (const r of references) lines.push(`- [@${r.citekey || r.id}] ${r.title || ''}`)
    lines.push('')
  }
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
  lines.push('**Must include.**')
  lines.push('')
  for (const m of spec.must_include || []) lines.push(`- ${m}`)
  lines.push('')
  if (finalists.length > 1) {
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
  }
  return lines.join('\n')
}

const markdown = buildMarkdown()

return {
  prose: winner.text,
  winning_register: winner.voice,
  reasoning: verdict.reasoning,
  spec,
  references: references.map(r => ({ citekey: r.citekey || r.id, title: r.title })),
  alternates: finalists.map(f => ({ voice: f.voice, text: f.text })),
  ranking: verdict.ranking,
  output_tokens: budget.spent(),
  markdown,
}
