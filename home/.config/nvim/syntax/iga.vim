if exists("b:current_syntax")
  finish
endif

syn case match

syn keyword igaOpcode mov sel csel movi smov add mul mac mad add3 addc subb mach macl mullh avg frc rndd rnde rndu rndz srnd lzd
syn keyword igaOpcode and or xor not shl shr asr rol ror bfe bfi1 bfi2 bfrev bfn cbit fbh fbl
syn keyword igaOpcode cmp cmpn math dp2 dp3 dp4 dph dp4a line pln lrp sad2 sada2
syn keyword igaOpcode dpas dpasw bdpas
syn keyword igaOpcode if else endif while break cont goto brd brc jmpi call calla ret halt nop join
syn keyword igaOpcode send sendc sends sendsc sendg sendgc wait sync illegal
syn match igaOpcode "\<send\.\w\+"
syn match igaOpcode "\<sync\.\(nop\|allrd\|allwr\|flush\|bar\|host\)\>"
syn match igaOpcode "\<math\.\w\+"
syn match igaOpcode "\<dpas\.\S\+"

syn match igaExecSize "(\d\+|M\d\+)"
syn match igaWrEn "(W\(&\|)\)\@="
syn match igaWrEn "(W)"
syn match igaPredicate "(\~\?f\d\.\d\(\.\(any\|all\)\d\+h\)\?)"

syn match igaRegister "\<r\d\+\(\.\d\+\)\?\>"
syn match igaRegister "\<null\>"
syn match igaARF "\<\(a0\|acc\d\?\|f\d\|tm0\|sr0\|cr0\|ce\|ip\|n0\|tdr\|dbg0\)\(\.\d\+\)\?\>"
syn match igaIndirect "r\[a0\.\d\+\(\s*,\s*\d\+\)\?\]"

syn match igaRegion "<\d\+;\d\+,\d\+>"
syn match igaRegion "<\d\+>"

syn match igaType ":\(ud\|d\|uw\|w\|ub\|b\|uq\|q\|f\|hf\|bf\|df\|tf32\|bf8\|hf8\|u4\|s4\|u2\|s2\|uv\|v\|vf\|e2m1\|e3m0\)\>"

syn match igaSWSB "{[^}]*}"
syn match igaSBID "\$\d\+\(\.\(dst\|src\)\)\?" containedin=igaSWSB contained

syn match igaNumber "\<0x\x\+\>"
syn match igaNumber "\<\d\+\(\.\d\+\)\?\>"
syn match igaLabel "^\s*\w\+:"

syn match igaComment "//.*$"
syn region igaComment start="/\*" end="\*/"

hi def link igaOpcode    Statement
hi def link igaExecSize  Special
hi def link igaWrEn      PreProc
hi def link igaPredicate PreProc
hi def link igaRegister  Identifier
hi def link igaARF       Constant
hi def link igaIndirect  Identifier
hi def link igaRegion    Type
hi def link igaType      Type
hi def link igaSWSB      Todo
hi def link igaSBID      Todo
hi def link igaNumber    Number
hi def link igaLabel     Label
hi def link igaComment   Comment

let b:current_syntax = "iga"
