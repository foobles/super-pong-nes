.charmap 32, $00            ; [space]

;;; letters
.repeat 26, I 
    .charmap 65+I, $01+I 
    .charmap 97+I, $01+I 
.endrepeat 

;;; digits
.charmap 48, $24            ; '0'
.repeat 9,I 
    .charmap 49+I, $1B+I    ; '1'-'9'
.endrepeat


.charmap 46,    $25 ; '.'
.charmap 44,    $26 ; ','
.charmap 33,    $27 ; '!'
.charmap 63,    $28 ; '?'
.charmap 96,    $29 ; '`'
.charmap 34,    $2A ; '"'
.charmap 39,    $2B ; '''
.charmap 58,    $2C ; ':'
.charmap 47,    $2D ; '/'
.charmap 35,    $2E ; '#'
.charmap 37,    $2F ; '%'
.charmap 38,    $30 ; '&'
.charmap 126,   $31 ; '~'
.charmap 43,    $32 ; '+'
.charmap 45,    $33 ; '-'
.charmap 91,    $37 ; '['
.charmap 93,    $38 ; ']'
.charmap 40,    $39 ; '('
.charmap 41,    $3A ; ')'
.charmap 60,    $3B ; '<'
.charmap 62,    $3C ; '>'