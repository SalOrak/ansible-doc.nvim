" Highlight lines starting with '# ' as headings
syntax match ansibledocHeading '^# .*$'
highlight def link ansibledocHeading Title

" Highlight special keywords anywhere
syntax keyword ansibledocKeyword IMPORTANT NOTE WARNING
highlight ansibledocKeyword guifg=red gui=bold

" Embed YAML in fenced blocks
syntax region ansibledocYAML matchgroup=Delimiter start="```yaml" end="```" contains=yamlTop
runtime! syntax/yaml.vim

