
DESET_SEKUNDI equ 10

timer_int:
	pusha
	push gs		; zbog moguceg menjanja DS-a od strane int 08h
	pop ds
	
	call	proveriDOSflagove					; provera da li je DOS zauzet
	cmp	byte [slobodan], 1				
	je prikazuj
	
	cmp	byte [idle], byte 1	; proveravamo da li je DOS zauzet jer ceka na neki I/O dogadjaj	(IDLE stanje)
	je		prikazuj									; ako je u IDLE stanju, mozemo da koristimo int 21h, ali samo za funkcije vece od 0ch
	jmp	timer_iret

proveriDOSflagove:
	pusha
	cli		; onemogucimo prekide, da npr. neki drugi TSR ne pozove int 21h
	mov		es, word [inDOSseg]
	mov		bx, word [inDOSoff]
	cmp		byte [es:bx], 0
	jne		_DOS_zauzet
	cmp		byte [es:bx-1], 0					; criticalDOS flag
	je		_DOS_slobodan

_DOS_zauzet:
	mov		byte [slobodan], 0
	jmp _provera_end

_DOS_slobodan:
	mov		byte [slobodan], 1

_provera_end:
	sti		; omogucimo prekide 
	popa
	ret
	
	
prikazuj:
	mov ah, 2ch
	int 21h
	cmp [sekunda], byte dh
	je timer_iret
	mov [sekunda], byte dh
	sub [vreme_smenjivanja], byte 1
	cmp [vreme_smenjivanja], byte 0
	je zameni_prikaz
	jmp timer_iret
	
	
zameni_prikaz:
	; prikaz sistemskog vremena na svakih 10 sekundi
	mov ax, 0b800h
	mov es, ax
	mov bx, word [pozicija]
	mov ax, cx
	shr ax, 8
	call time2str
	mov [es:bx], byte ':'
	add bx,2
	
	mov ax, cx
	and ax, 00ffh
	call time2str
	mov [es:bx], byte ':'
	add bx, 2
	
	mov ax, dx
	shr ax, 8
	call time2str
	add bx, 144	; namestamo poziciju za ispis labele registara/steka
	
	
	mov [vreme_smenjivanja], byte DESET_SEKUNDI
	cmp [zamena], byte 1
	je prikaz_steka
	
	
prikaz_registara:
	mov [zamena], byte 1	; menjamo flag, da bi se sledeci prikazao stek

	; prvo se ispisuju nazivi registara
	mov si, reg_label
	call ispis_vrednosti_labele 
	 
	 ; sad se ispisuju vrednosti registara
	;ax
	call hex_to_string
	;bx
	mov ax, bx
	call hex_to_string
	;cx
	mov ax, cx
	call hex_to_string
	;dx
	mov ax, dx
	call hex_to_string
	;si
	mov ax, si
	call hex_to_string
	;di
	mov ax, di
	call hex_to_string
		
	jmp timer_iret

	

prikaz_steka:
	mov [zamena], byte 0	; menjamo flag, da bi se sledeci prikazali registri
	
	; prvo se ispisuje vrednost labele
	mov si, stk_label
	call ispis_vrednosti_labele 
	
	; sad se ispisuju vrednosti sa steka
	mov bp, sp
	mov si, 0
	mov cx, 6
	_ispis_vrednosti_steka:
		mov ax, [ss:bp+si]
		add si, 2
		push cx	; jer se cx promeni u funkciji hex_to_string
		call hex_to_string
		pop cx
		loop _ispis_vrednosti_steka
	
	jmp timer_iret
	
	
	
ispis_vrednosti_labele:
	  pusha
	  cld
	  _petlja_labela:
		lodsb             
		or   al,al     
		jz  _labela_kraj         ; kraj stringa 
		mov [es:bx], byte al
		add bx, 2
		cmp al, byte 'h'
		jne _petlja_labela
		add bx, 142
		jmp _petlja_labela   
	  
	  _labela_kraj:
		popa
		mov bx, word [pozicija_vrednosti]
		ret
		
		
hex_to_string:
	push ax
	mov ax, 0b800h
	mov es, ax
	pop ax
	
	mov cx, 4
	_citaj_nibl:
		push ax
		
		cmp cx, 4
		je _shift_12
		cmp cx, 3
		je _shift_8
		cmp cx, 2
		je _shift_4
		jmp _anduj	; ako treba da se siftuje za 0, samo andujemo
		_shift_12:
			shr ax, 12
			jmp _anduj
		_shift_8:
			shr ax, 8
			jmp _anduj
		_shift_4:
			shr ax, 4

		_anduj:
		and ax, 000fh
		cmp ax, 9
		jle _cifra
		; ako nije cifra, onda su u pitanju vrednosti A,B,C,D,E,F
		add ax, 55
		jmp _hex_bajt
		
		_cifra:
			add ax, 48
		
		_hex_bajt:
			mov [es:bx], byte al
			add bx, 2
			pop ax
			loop _citaj_nibl
		
	_hex_kraj:
		add bx, word 152
		ret
		
		

_peekuj:
		pusha
		
		mov si, word seg_off_val_label
		mov bx, word [pp_pozicija]
		call ispis_vrednosti_labele
		
		mov si, di
		add si, 8 ; dolazimo do prve cifre segmenta da bi prebacili string u hex vrednost
		
		call _string_to_int_or_hex
		mov [seg_str_val], word ax
		
		; dolazimo do prve cifre offseta
		add si, 5
		call _string_to_int_or_hex
		mov [off_str_val], word ax
		
		mov si, di
		add si, 8 ; dolazimo opet do prve cifre segmenta zbog ispisivanja na ekran

		_pp_ispis:
		mov bx, word [pp_pozicija_vrednosti]
		cld
		
		_petlja_pp:
			lodsb
			cmp al, byte ' '
			je _k
			cmp al, byte 13 ; enter
			je _k
			mov [es:bx], byte al
			add bx, 2
			jmp _petlja_pp
			_k:
				add bx, 152
				cmp al, byte ' '
				je _petlja_pp
				
				mov ax, word [seg_str_val]
				mov es, ax
				mov bx, word [off_str_val]
				
				
				mov di, 080h
				mov al, byte [di];
				cmp al, byte 16
				je _pik
				
				; PROVERI DA LI JE OVO U REDU (U REDU JE)
				xor ax, ax
				mov al, byte [val_str_val]
				mov [es:bx], byte al
				; nema popa, jer smo dosli iz _pokeuj funkcije
				ret
				
				_pik:
					xor ax,ax
					mov al, byte [es:bx] 
					mov bx, [pp_pozicija_segoff_val]
					
					call hex_to_string
					
				_pp_end:
					popa
					ret
		
		

		
_pokeuj:
		pusha
		
		mov si, word seg_off_val_label
		mov bx, word [pp_pozicija]
		call ispis_vrednosti_labele

		mov si, di
		add si, 13 ; dolazimo do prve cifre segmenta da bi prebacili string u hex vrednost
		
		call _string_to_int_or_hex
		mov [seg_str_val], word ax
		
		; dolazimo do prve cifre offseta
		add si, 5
		call _string_to_int_or_hex
		mov [off_str_val], word ax
		
		; dolazimo do prve cifre vrednosti koju hocemo na zadatu adresu da stavimo
		add si, 5
		call _string_to_int_or_hex
		mov [val_str_val], word ax
		
		mov si, di
		add si, 13 ; dolazimo opet do prve cifre segmenta zbog ispisivanja na ekran
		
		call _pp_ispis
		
		popa
		ret
	
	

procitaj_fajl:
	pusha
	
	;otvorimo datoteku in.txt za citanje
	mov ah, 3dh ;operacija OPEN
	mov al, 0 ;access mode: 0 = read, 1 = write, 2 = read+write
	mov dx, ime_in ;ime datoteke ide u DX
	int 21h ;izvrsavamo otvaranje; file handle je u AX
	
	;procitamo datoteku in.txt
	mov bx, ax ;cuvamo file handle u BX
	mov ah, 3fh ;operacija READ
	mov cx, 256 ;citamo maksimalno 256 bajtova
	mov dx, podaci ;dx pokazuje na bafer u koji smestamo podatke
	int 21h ;izvrsavamo citanje, broj procitanih bajtova je u AX
	;zatvorimo datoteku in.txt
	mov ah, 3eh ;operacija CLOSE
	;bx je vec postavljen
	int 21h  ;izvrsavamo operaciju zatvaranja; nema povratne vrednosti
	
	
	; cuvanje vrednosti kolone i reda u osnovi 10
	mov si, dx
	call _string_to_int_or_hex
	mov [kolona], word ax
	add si, 4								; dolazimo do prve cifre u narednom redu u fajlu
	call _string_to_int_or_hex	; u fajlu nakon drugog reda cifara mora
												; da ide enter, da bi se dobro konvertovalo
	mov [red], word ax
	
	mov [file_pos], byte 0	; samo pri startovanju tsr-a vrednost [file_pos] je 1
	
	; namestamo tacnu poziciju u video memoriji
	mov cx, word [red]
	mov bx, 0
	cmp cx, word 0
	je preskoci_red
	
	red_p:
		add bx, 160
		loop red_p
	
	preskoci_red:
	add bx, word [kolona]
	add bx, word [kolona]
	
	mov [pozicija], word bx
	add bx, 168
	mov [pozicija_vrednosti], word bx
	mov bx, word [pozicija]
	add bx, 1120
	mov [pp_pozicija], word bx
	add bx, 8
	mov [pp_pozicija_vrednosti], word bx
	add bx, 320
	mov [pp_pozicija_segoff_val], word bx

	popa
	ret
	
MyInt28:
	push ds
	pusha
	
	mov ax, word [old28_seg]
	mov es, ax
	pushf
	call far [es:old28_off]
	
	mov [idle], byte 1
	
	pop ds
	popa
	iret
	
timer_iret:
	popa
	sti
	iret
	
	
Idle_ISR:
	mov [idle], byte 1
	
	push word [cs:old28_seg]
	push word [cs:old1C_off]
	retf


	
	
_novi_1C:
	cli
	xor ax, ax
	mov es, ax
	mov bx, [es:1Ch*4]
	mov [old1C_off], bx 
	mov bx, [es:1Ch*4+2]
	mov [old1C_seg], bx

	mov dx, timer_int
	mov [es:1Ch*4], dx
	mov ax, cs
	mov [es:1Ch*4+2], ax  
	push ds
	pop gs
	sti 
	ret


_stari_1C:
	cli
	xor ax, ax
	mov es, ax
	mov ax, [old1C_seg]
	mov [es:1Ch*4+2], ax
	mov dx, [old1C_off]
	mov [es:1Ch*4], dx
	sti
	ret
	
	
_novi_28:
	cli
	xor 	ax, ax
	mov 	es, ax
	mov 	bx, [es:28h*4]
	mov 	[old28_off], bx
	mov 	bx, [es:28h*4+2]  
	mov		[old28_seg], bx

	mov 	dx, Idle_ISR
	mov 	[es:28h*4], dx
	mov 	ax, cs
	mov 	[es:28h*4+2], ax
	sti         
	ret
	
_stari_28:
	cli
	xor 	ax, ax
	mov 	es, ax
	mov 	bx, [old28_off]	
	mov 	[es:28h*4], bx
	mov		bx, [old28_seg]
	mov 	[es:28h*4+2], bx
	sti
	ret
	
	
%include 'str2int.asm'

vreme_smenjivanja: db 1		; vreme na koje se prikazi smenjuju
sekunda: db 0							; da se zna kad prodje sekund
zamena: db 0							; flag - da li je proslo 10 sekundi
pozicija: dw 0							; pozicija iz fajla (kolona, red)
pozicija_vrednosti: dw 0			; pozicija vrednosti registara/steka
pp_pozicija: dw 0					; pozicija peek_poke labele
pp_pozicija_vrednosti: dw 0 	; pozicija peek_poke seg i off vrednosti
pp_pozicija_segoff_val: dw 0	; pozicija peek_poke seg_off value-a
ime_in: db 'pos.txt',0				; naziv fajla iz koga se cita pozicija ispisa
podaci:  times 10 db 'x'			; podaci iz fajla pos.txt
kolona: dw 0							; kolona na kojoj ispis treba da pocne
red: dw 0									; red na kojoj ispis treba da pocne
slobodan: db 0						; flag za inDOS i criticalDOS
idle: db 0									; flag za IDLE interrupt 28h

seg_str_val: dw 0	;	string segmenta pretvoren u hex sa komandne linije
off_str_val:   dw 0	;	string offseta	   pretvoren u hex sa komandne linije
val_str_val:	 dw 0	; 	string byte-a (kod poke komande) pretvoren u hex sa komandne linije


old1C_seg: 	dw 0
old1C_off: 	dw 0
old28_seg:	dw 0
old28_off:	dw 0


reg_label: 
db 'ax :',' ',' ',' ',' ','h'
db 'bx :',' ',' ',' ',' ','h'
db 'cx :',' ',' ',' ',' ','h'
db 'dx :',' ',' ',' ',' ','h'
db 'si :',' ',' ',' ',' ','h'
db 'di :',' ',' ',' ',' ','h',0

stk_label: 
db '1  :',' ',' ',' ',' ','h'
db '2  :',' ',' ',' ',' ','h'
db '3  :',' ',' ',' ',' ','h'
db '4  :',' ',' ',' ',' ','h'
db '5  :',' ',' ',' ',' ','h'
db '6  :',' ',' ',' ',' ','h',0

seg_off_val_label:
db 'seg:',' ',' ',' ',' ','h'
db 'off:',' ',' ',' ',' ','h'
db 'val:',' ',' ',' ',' ','h',0