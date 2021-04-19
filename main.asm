org 100h

START 	   equ 7 ; -start ima 7 karaktera zbog entera
STOP	   equ 6; -stop ima 6 karaktera zbog entera
PEEK	   equ 16; -peek aabb ccdd ima 16 karaktera zbog entera
POKE	   equ 24; -poke byte aabb ccdd ee ima 24 karaktera zbog entera



komandna_linija:
	; push ds
	mov di, 0080h                   
	mov al, byte [di]
	mov [status], byte al
	
	call TransientTSR		; startujemo tsr ako vec nije startovan
	
	
	cmp [tsr_is_present], byte 1
	je	tsr_prisutan
	jmp tsr_nije_prisutan
	
	tsr_prisutan:
	mov di, 80h
	mov al, byte [di]
	mov [status], byte al
	
	mov ax, 0b800h
	mov es, ax
		
		cmp [status], byte START
		jne _pr_pp
		mov si, greska_msg
		jmp ispis_stanja
		
		_pr_pp:
		cmp [status], byte PEEK
		jne .po
		call _peekuj
		jmp kraj
		
		.po:
		cmp [status], byte POKE
		jne .st
		call _pokeuj
		jmp kraj
		
		.st:
		cmp [status], byte STOP
		je rmvTsr
		mov si, greska_msg
		jmp ispis_stanja
		
		rmvTsr:
			call _stari_1C
			; mov al, 1	; 'flag' da zelimo da obrisemo nas TSR
			call removeTSR
			mov si, stop_msg
			jmp ispis_stanja
			
	tsr_nije_prisutan:
		cmp [status], byte START
		je _startuj
		mov si, greska_msg
		jmp ispis_stanja
		

		
	_startuj:
		mov [tsr_is_present], byte 1
		call procitaj_fajl				; racunamo poziciju od koje ispis treba da pocne
		mov ah, 2ch
		int 21h
		mov [sekunda], byte dh	; zbog provere kad prodje sekund
		
		; hocemo da sacuvamo inDOS flag pre provere da li je DOS slobodan
		mov		ah, 34h						
		int		21h
		mov		ax, es
		mov		[inDOSseg], ax
		mov		[inDOSoff], bx
		
		call _novi_1C
		mov si, start_msg
		call ispis_stanja
		mov 	dx, 00ffh
		mov		ah, 31h						
		int		21h							
		
	
		
ispis_stanja:
		mov ax, 0b800h
		mov es, ax
		mov bx, 60
		cld
		_ispis:
			lodsb
			cmp al, 0
			je _pr_kraj
			mov [es:bx], al
			inc bx
			mov [es:bx], byte 3
			inc bx
			jmp _ispis
			
		_pr_kraj:
			cmp [status], byte START
			jne kraj
			ret
			
kraj:
		; pop ds
		ret
		
%include 'prikaz.asm'
%include 'tsr.asm'

status: db 0
greska_msg:  db 'G R E S K A . . .',0
start_msg:	  db 'S T A R T O V A N',0
stop_msg:	  db 'T S R  TERMINATED',0
inDOSseg: 	  dw 0
inDOSoff:   	  dw 0
