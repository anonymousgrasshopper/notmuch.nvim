syntax match nmHelloTags "^.*$"
highlight link nmHelloTags Include

" ----------------------------------------------------------
" Saved/Pinned queries section
" ----------------------------------------------------------

syntax match nmSavedHeader   "^Saved/Pinned:$"
syntax match nmSavedSep      "^-\+$"
syntax match nmSavedName     "^\s\+\zs.\{-}\ze -- "         contained
syntax match nmSavedQueryStr "`[^`]*`"                       contained
syntax match nmSavedLine     "^\s\+.\+ -- `[^`]*`$"         contains=nmSavedName,nmSavedQueryStr

highlight link nmSavedHeader   Title
highlight link nmSavedSep      Comment
highlight link nmSavedName     Identifier
highlight link nmSavedQueryStr Statement

" ----------------------------------------------------------
" nmHints:
" First line always contains the Hints with key combinations
" ----------------------------------------------------------

syntax region nmHints		start=/^Hints:/ end=/$/		oneline	contains=nmHintsIdentifier
syntax match nmHintsIdentifier	"^Hints:"			contained nextgroup=nmHintsKey
syntax match nmHintsKey		"\s\+[^:\s]\+"			contained nextgroup=nmHintsKVDelimiter
syntax match nmHintsKVDelimiter	":"				contained nextgroup=nmHintsValue
syntax match nmHintsValue	"\s\+[A-Za-z0-9\ ]\+"		contained nextgroup=nmHintsDelimiter
syntax match nmHintsDelimiter	"|"				contained nextgroup=nmHintsKey

highlight link nmHintsIdentifier	Comment
highlight link nmHintsKey		Include
highlight link nmHintsKVDelimiter	Comment
highlight link nmHintsValue		Normal
highlight link nmHintsDelimiter		Comment
