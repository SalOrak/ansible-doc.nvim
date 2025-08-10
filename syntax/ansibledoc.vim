silent! syntax clear ansibledoc

" Highlight lines starting with '# ' as headings
syntax match adTitle '^# .*$' keepend
highlight def link adTitle Title

" Highlight lines starting with '# ' as headings
syntax match adItem '^* .*$' keepend
highlight link adItem Label

" Highlight Inline Code with ``
syntax region adInlineCode start="`" end="`" keepend 
highlight def link adInlineCode Constant

" Highlight Code in module with ``
syntax region adCodeInMod start="C(" end=")" keepend 
highlight def link adCodeInMod Constant

" Highlight Module in module with ``
syntax region adModuleInMod start="M(" end=")" keepend 
highlight def link adModuleInMod Underlined

" Highlight Value in module with ``
syntax region adValueInMod start="V(" end=")" keepend 
highlight def link adValueInMod Identifier

" Highlight Return in module with ``
syntax region adVerboseInMod start="R(" end=")" keepend 
highlight def link adVerboseInMod Structure

" Highlight Optional modules
syntax region adOptionalModule start="\t\~" end="\~" keepend 
highlight def link adOptionalModule String
"
" " Highlight Required modules
syntax region adRequiredModule start="\t\[" end="\]" keepend
highlight link adRequiredModule Exception

" " Highlight Attributes modules
syntax region adAttribute start="\t|" end="|" keepend
highlight link adAttribute Identifier


" Embed YAML in fenced blocks
syntax include @adyaml syntax/yaml.vim


syntax region adYAML start="^```yamlStart$" end="^```yamlEnd$" contains=@adyaml keepend

syntax sync match myYAMLSync grouphere adYAML /^```yamlStart/
syntax sync match myYAMLSync groupthere adYAML /^```yamlEnd/

highlight link adYAML Normal


