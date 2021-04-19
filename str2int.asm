

_string_to_int_or_hex:
pusha
mov [rezultat], word 0

petlja:
	lodsb
	cmp al, ' '
	je str_izlaz
	cmp al, 13 ; enter
	je str_izlaz

	cmp al, 96
	jle _cifra_znak
	; ako je >= 65, onda su u pitanju znakovi A,B,C,D,E,F
	sub al, 87
	jmp racun
	_cifra_znak:
	sub al, 48
	
	racun:
	push ax		; hocu da sacuvam vrednost iz AL
	mov ax, [rezultat]
	cmp [file_pos], byte 1
	je base_ten	
	
	mov bx, 16
	jmp racun_continue
	
	base_ten:
	mov bx, 10
	
	racun_continue:
	mul bx
	mov [rezultat], dx	; visi deo proizvoda je u DX
	add [rezultat], ax	; nizi deo proizvoda je u AX
	pop ax		; skidam sacuvanu vrednost iz AL
	add [rezultat], al
	jmp petlja
	
time2str:
	push bx
	mov bl, 10	
	div bl
	pop bx
	
	add al, 48
	mov [es:bx], byte al
	add bx, 2
	add ah, 48
	mov [es:bx], byte ah
	add bx, 2	
	ret
	
str_izlaz:
	popa
	mov ax, [rezultat]
	ret	

rezultat: dw 0
file_pos: db 1