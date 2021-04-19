

TransientTSR:
	mov		cx, 00FFh	
SearchLoop:
	mov		ah, cl					
	push	cx
	mov		al, 0
	int		2Fh	
	pop		cx

	cmp		al, 0
	je		.saveAndNext	
	
	push	cx
	cld
	mov     si, TSRname
	mov     cx, 5
	repe    cmpsb
	pop		cx
	je		.alreadyThere				
	loop	SearchLoop
	jmp		.install					
.saveAndNext:
	mov		byte [tsrID], cl
	loop	SearchLoop
	jmp		.install
.alreadyThere:
	
	call prepisi_cmd	; prepisujemo komandnu liniju trenutnog taska
						; preko komandne linije naseg tsr-a
	
	; vracam stari ds, jer se trenutno nalazimo u ds-u trenutnog taska
	push gs			
	pop ds
	
	jmp		Exit
.install:
	cmp		byte [tsrID], 0	; ukoliko je tsrID > 0, znaci da 'ima mesta' i za nas
	jne		GoodID
Exit:
	ret

GoodID:
	cmp [status], byte START
	jne Exit
	call	MyNew2F
	mov		ah, 51h		
	int		21h
	mov		[cs:PSP], bx
	ret

MyNew2F:
	cli
	xor 	ax, ax
	mov 	es, ax
	mov 	bx, [es:2Fh*4]
	mov 	[old2F_off], bx
	mov 	bx, [es:2Fh*4+2]  
	mov		[old2F_seg], bx

	mov 	dx, MyInt2F
	mov 	[es:2Fh*4], dx
	mov 	ax, cs
	mov 	[es:2Fh*4+2], ax
	sti         
	ret

MyInt2F:
	cmp		ah, [cs:tsrID]
	je		.itsUs
	
	push word [cs:old2F_seg]
	push word [cs:old2F_off]
	retf
	
.itsUs:
	mov		ax, cs
	mov		es, ax
	mov		di, TSRname
	mov		al, 0FFh
	iret
	
removeTSR:
	cli
	xor 	ax, ax
	mov 	es, ax
	mov 	bx, [ds:old2F_off]	; vracamo stari multiplekserski vektor prekida
	mov 	[es:2Fh*4], bx
	mov		bx, [ds:old2F_seg]
	mov 	[es:2Fh*4+2], bx
	
	
	mov		es, [ds:PSP]		; prvo oslobadjamo memoriju dodeljenu enviroment block-u
	mov		es, [es:2Ch]
	mov		ah, 49h
	int		21h

	mov		es, [ds:PSP]		; a zatim oslobadjamo memoriju dodeljenu nasem TSR-u
	mov		ah, 49h
	int		21h
	
	sti
	ret
	
prepisi_cmd:
pusha
	mov di, 80h
	mov si, di
	cld
	_psp_iter:
		lodsb
		cmp al, 13	; enter
		je _chng_end
		mov [gs:di], byte al
		inc di
		jmp _psp_iter
	
	_chng_end:
		mov [gs:di], byte 13	; da osiguramo argumente sa enterom na kraju
		popa
		ret
		
z: db 65	; 'debugger'
tsr_is_present: db 0
old2F_seg:	dw 0
old2F_off:	dw 0
tsrID:			db 0
TSRname:	db 'myTSR'
PSP:				dw 0
AppPSP:		dw 0