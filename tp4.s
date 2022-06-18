
; Autor:     Manuel Fonseca   n: 48052
; Autor:	 Manuel Henriques n: 47202
; Autor:	 Tiago Pardal 	  n: 47206




; Definicao dos valores dos simbolos utilizados no programa
; valores calculados para o pico timer ligado a 1khz

	.equ	STACK_SIZE, 64           ; Dimensao do stack (em bytes)

	.equ    INPORT_ADDRESS, 0xFF00  ; Endereço do porto de entrada da placa SDP16
	.equ	OUTPORT_ADDRESS, 0xFF00 ; Endereço do porto de saida da placa SDP16

	.equ	CPSR_BIT_I, 0x10          ; Mascara para a flag I do registo CPSR
	.equ	PTC_VALUE, 50			; Intervalo de contagem do circuito pTC ; valores calculados para o pico timer ligado a 1khz
	
                                        ; que suporta a implementação do sysclk
										; fin_pTC = 1kHz fout_ptc=20Hz => T=50ms 
										
	.equ 	LED0_MASK, 0x01
	.equ 	OUTPORT_INIT_VALUE, 0x00

	.equ 	IE_MASK,0x10

	.equ    pTC_ADDRESS, 0XFF40
	.equ    pTC_TCR, 0
	.equ    pTC_TMR, 2
	.equ    pTC_TC,  4
	.equ    pTC_TIR, 6
	
	.equ    pTC_CMD_STOP,  1
	.equ    pTC_CMD_START, 0

	.equ 	PLAYER_MASK, 0X80
	.equ	WALL_MASK,   0X02
	.equ 	NEW_POINT_LED_MASK, 0X1
	.equ	LEVEL_INPUT_MASK, 0xc0
	.equ	BALL_LEDS_MASK, 0xfe
	.equ 	RAKET_MASK, 0x01
	.equ 	LVL_MASK, 0xc0
	.equ	VALUE_OF_1S, 20	;0.05 * 20 = 1s
	.equ	VALUE_OF_5S, 100	;0.05 * 100 = 5s
	.equ	VALUE_OF_25, 5		;0.05 * 5 = 2.5s

	.equ	VARIANT_LEVEL, 3

; Seccao:    .startup
; Descricao: Guarda o código de arranque do sistema
;
	.section .startup
	b 	_start
	ldr	pc, isr_addr

_start:
	ldr sp, tos_addr
	bl SYS_init
	ldr	pc, main_addr

tos_addr:
	.word	tos
main_addr:
	.word	main
isr_addr:
	.word	isr
	
;----------------------------------------	
;# define OUTPORT_INIT_VALUE 0
;# define LED0_MASK 1
;
;uint16_t ticks = 0;
; 
;void main() {
;uint16_t t;
;	outport_init ( OUTPORT_INIT_VALUE );
;	timer_init ( SYSCLK_FREQ );
;   //Habilitar o atendimento das interrupcoes
;   while(1) {
;		outport_set_bits(LED0_MASK);
;		t = sysclk_get_value ();
;		while ( sysclk_elapsed ( t ) < LED_TOGGLE_TIME );
;		outport_clear_bits(LED0_MASK);
;		t = sysclk_get_value ();
;		while ( sysclk_elapsed ( t ) < LED_TOGGLE_TIME );
;   }
;}
;----------------------------------------	
	.text
SYS_init:
	push lr
	bl outport_init		
	bl timer_stop
	ldr		r0, ticks_addr
	ldr		r1, [r0, #0]
	mov		r1,  #0
	str		r1, [r0, #0]
	mov r0, PLAYER_MASK	;posição de inicio do jogo
	ldr r1, ball_pos_addr
	strb r0, [r1]
	
	mov r0, PTC_VALUE
	bl timer_init		

	mov r0, IE_MASK
	msr cpsr, r0	
	pop pc	
	
ball_pos_addr:
	.word 	ball_pos	
	
ticks_addr:
	.word ticks

main:
	push lr	
	bl timer_stop
	ldr r0, direction_addr
	mov r1, 0
	strb r1, [r0]
	b main_while
	
direction_addr:
	.word	direction
	
main_while:
	bl reset_all
	bl set_ball_leds
	
wait_for_init_stroke:
	mov r0, RAKET_MASK
	bl sw_is_pressed
	add r0,r0,0
	bzc start_game  
	b    wait_for_init_stroke
	
start_game:
	bl set_level_dif
	bl timer_start
	bl init_timer_lvl
	bl init_timer_1s
	bl mov_ball
	bl set_ball_leds

game_loop:
	mov r0, RAKET_MASK
	bl sw_is_pressed
	bl get_timer_1s
	bl sysclk_elapsed
	mov r1, VALUE_OF_1S
	cmp r0, r1 ;20
	blo one_second_pass_spik
	bl one_second_pass

one_second_pass_spik:	
	ldr r0, new_point_led_addr
	ldrb r0,[r0]
	sub r0,r0,0
	bzs time_lvl
	
	bl get_timer_1s
	bl sysclk_elapsed
	mov r1, VALUE_OF_25
	cmp r0, r1 		;5
	blo	time_lvl	
	mov r0, 0
	bl set_led_newpoint
	
time_lvl:
	bl get_timer_lvl
	bl sysclk_elapsed
	mov r1, r0
	bl get_level_dif
	cmp r1, r0
	blo await_time_or_player
	
	bl init_timer_lvl 
	bl get_ball_position
	mov r2, PLAYER_MASK
	sub r0, r0, r2
	bzc next_move_dir
	b game_over

; averigua direção em que a bola se deve movimentar
next_move_dir:
	bl get_ball_position
	sub r0, r0, WALL_MASK
	bzc continue_game
	bl invert_dir
	
continue_game:
	bl mov_ball
	bl set_ball_leds
	bl init_timer_lvl

; verifica se o jogador já jogou no caso de a bola se encontrar à frente dele
await_time_or_player:	
	;verifica se a bola se encontra no jogador
	bl get_ball_position
	mov r2, PLAYER_MASK
	sub r0, r0, r2	
	bzc game_loop
	
	;verifica se butão foi premido
	;se o jogador moveu a raquete
	mov r0, RAKET_MASK
	bl sw_is_pressed
	add r0,r0,0
	bzs  game_loop
	
	bl invert_dir
	bl continue_game
	b game_loop


;apresenta do score no porto de saída durante 5 segundos
game_over:
	bl invert_dir
	bl outport_clear_bits
	bl get_score
	bl outport_set_bits
	bl init_timer_5s
	mov r4, VALUE_OF_5S
	
game_over_loop:
	bl get_timer_5s
	bl sysclk_elapsed
	cmp r0, r4			;wait 5s
	blo game_over_loop
	bl timer_stop
	b  main_while 	

new_point_led_addr:
	.word 	new_point_led
	
	
; incrementa score e apresenta indicador de ponto
one_second_pass:
	;SCORE ++
	;LED ON NEW POINT
	;INIT TIMER
	push lr
	bl init_timer_1s
	mov r0, 1
	bl set_led_newpoint
	bl add_score
	pop pc
	
	
; set led new point to the valu of r0	
set_led_newpoint:
	push lr
	ldr r1, new_point_led_addr_ext
	strb r0, [r1]
	mov r1,r0
	mov r0, NEW_POINT_LED_MASK
	bl	outport_write_bits
	pop pc
	
new_point_led_addr_ext:
		.word	new_point_led


;-------------------------------------------------------------------------
; Funções relacionadas com a bola
;-------------------------------------------------------------------------

set_ball_leds:
	push lr	
	ldr	r1, ball_pos_addr_ext1
	ldrb r1, [r1]
	mov r0, BALL_LEDS_MASK
	bl	outport_write_bits	
	pop pc

invert_dir:
	push lr
	ldr r0, direction_addr_ext
	ldrb r1, [r0]
	mov r2, 1
	eor r1, r1, r2
	strb r1, [r0]
	pop pc

get_direction:
	ldr r0, direction_addr_ext
	ldrb r0, [r0]
	mov pc, lr

get_ball_position:
	ldr r0, ball_pos_addr_ext1
	ldrb r0, [r0]
	mov pc, lr

ball_pos_addr_ext1:
	.word 	ball_pos

direction_addr_ext:
	.word	direction

;-------------------------------------------------------------------------
; Funções relacionadas com timers
;-------------------------------------------------------------------------

init_timer_1s:
	push lr
	bl sysclk_get_value	
	ldr r1, timer_1s_addr
	str r0, [r1]	
	pop pc

get_timer_1s:
	ldr r0, timer_1s_addr
	ldr r0, [r0]
	mov pc, lr
	
timer_1s_addr:
	.word 	timer_1s


init_timer_5s:
	push lr
	bl sysclk_get_value	
	ldr r1, timer_5s_addr
	str r0, [r1]	
	pop pc

get_timer_5s:
	ldr r0, timer_5s_addr
	ldr r0, [r0]
	mov pc, lr
	
timer_5s_addr:
	.word 	timer_5s
	
;-------------------------------------------------------------------------
; Funções relacionadas com nivel
;-------------------------------------------------------------------------

init_timer_lvl:
	push lr
	bl sysclk_get_value	
	ldr r1, timer_level_addr
	str r0, [r1]	
	pop pc

get_timer_lvl:
	ldr r0, timer_level_addr
	ldr r0, [r0]
	mov pc, lr

get_level_dif:
	ldr r0, current_lvl_addr
	ldrb r0, [r0] 
	mov pc, lr
	
set_level_dif:
	push lr
	bl inport_read
	mov r1, LEVEL_INPUT_MASK
	and r0, r1, r0
	lsr r0, r0, #6
	mov r1, VARIANT_LEVEL
	cmp r0, r1
	beq set_level_dif //TODO

	ldr r1, lvl_list_addr
	ldrb r0, [r1, r0]	//lvl_list + input lvl as offset
	ldr r1, current_lvl_addr
	strb r0, [r1]
	pop pc


timer_level_addr:
	.word timer_level

lvl_list_addr:
	.word lvl_in_time

current_lvl_addr:
	.word current_lvl_dificult_in_time

;-------------------------------------------------------------------------
; Funções relacionadas com score
;-------------------------------------------------------------------------
	
get_score:
	push lr
	ldr r1, score_addr
	ldr r0, [r1]
	pop pc
	
add_score:	
	push lr
	ldr r0, score_addr
	ldr r1, [r0]
	add r1, r1, 1
	str r1, [r0]
	pop pc

	
;-------------------------------------------------------------------------
; Rotina:    mov_ball
; Descricao: R
; Entradas:  -
; Saidas:    -
; Efeitos:   Move bola em função de direção
;			  Na direção do player ou da parede
; void mov_ball() {
;   
;}	
mov_ball:
	push lr
	bl get_direction
	mov r1, r0
	bl get_ball_position
	mov r2, 1
	and r1,r1,r2
	sub r1, r1, 0	
	bzs mov_away
	;move from wall to player (BALL_POS6)01 -> (BALL_POS0)07   
	lsl r0, r0,1	
	b finish_mov
mov_away:
	lsr r0, r0,1
	
finish_mov:
	ldr r1, ball_pos_addr_ext2
	strb r0, [r1]
	pop pc

	
ball_pos_addr_ext2:
		.word ball_pos

;-------------------------------------------------------------------------
; Funcao para preparar o inicio de um novo jogo
; Para o contador, limpa o e limpa o score
;-------------------------------------------------------------------------
reset_all:
	push	lr
	bl timer_stop
	;timer sysclk  = 0	
	ldr		r1, ticks_addr_ext
	mov r0, 0
	str		r0, [r1, #0]	
	;score = 0
	ldr		r1, score_addr
	mov r0, 0
	str		r0, [r1, #0]	
	
	pop		pc

	
score_addr:
	.word	score
	
;-------------------------------------------------------------------------
; Rotina:    isr
; Descricao: Rotina responsavel pelo processamento do pedido de interrupcao.
; Entradas:  -
; Saidas:    -
; Efeitos:   Incrementa o valor da variavel global ticks
; void isr() {
;   ticks++;
;	//clear Interrupt Request
;}
isr:
	; Prologo
	push	r0
	push	r1
	push	r2
	; Corpo da rotina
	ldr		r0, ticks_addr_ext
	ldr		r1, [r0, #0]
	add		r1, r1, #1
	str		r1, [r0, #0]
	; clear Interrupt Request
	mov r1, 0xFF
	ldr  r0, ptc_addr
	strb r1, [ r0, #pTC_TIR ]
	; Epilogo
	pop		r2
	pop		r1
	pop		r0
	movs	pc, lr
	
	
timer_clearInterrupt:
	mov r0, 0
	ldr r1, timer_addr
	strb r0, [ r1, #pTC_TIR ]
	mov pc, lr
	

;-------------------------------------------------------------------------
;Funcao para devolver o valor corrente da variável global ticks.
;uint16_t sysclk_get_value ( void );
;	return ticks;
;-------------------------------------------------------------------------
sysclk_get_value:
	ldr		r1, ticks_addr_ext
	ldr  	r0, [r1, #0] 	; r0 = ticks
	mov		pc, lr

;-------------------------------------------------------------------------
;Funcao para devolver o tempo decorrido desde o instante last_read. 
;O tempo e medido em unidades de contagem ( ticks ).
;uint8_t sysclk_elapsed ( uint16_t last_read ){
;	return ( ticks - last_read )
;}
;-------------------------------------------------------------------------
sysclk_elapsed:
	ldr	 r1, ticks_addr_ext
	ldr  r2, [r1, #0] 	; r0 = ticks
	sub  r0, r2, r0
	mov  pc,lr

ticks_addr_ext:
	.word ticks
	
;-------------------------------------------------------------------------
;Funcao para iniciar a contagem no periferico.
;void timer_start ( void );
;-------------------------------------------------------------------------
timer_start:
	mov  r1, #pTC_CMD_START
	ldr  r0, ptc_addr
	strb r1, [ r0, #pTC_TCR ]
	mov  pc, lr


timer_write:
	ldr 	r2, timer_addr
	add		r0, r0, r0
	strb 	r1, [r2,r0]	
	mov		pc,lr

timer_addr:
	.word  pTC_ADDRESS	
;-------------------------------------------------------------------------
;Funcao para parar a contagem no periferico. 
;Colocando o contador com o valor zero.
;void timer_stop ( void );
;-------------------------------------------------------------------------
timer_stop:
	mov  r1, #pTC_CMD_STOP
	ldr  r0, ptc_addr
	strb r1, [ r0, #pTC_TCR ]
	mov  pc, lr

;-------------------------------------------------------------------------
;Funcao que faz a iniciacao do periferico para habilitar o 
;funcionamento em modo continuo e com intervalo de contagem 
;interval, em ticks.
;void timer_init ( uint8_t interval );
;-------------------------------------------------------------------------
timer_init:
	push lr
	push r0				
	; Parar contagem
	bl   timer_stop
	; Programar intervalo de contagem
	pop	 r0
	ldr  r1, ptc_addr
	strb r0, [ r1, #pTC_TMR ]
	; Clear Interrupt Request
	ldr  r1, ptc_addr
	strb r0, [ r1, #pTC_TIR ]
	pop  pc
	
ptc_addr:
	.word pTC_ADDRESS

;---------------------------------------------------------------------------------	
;uint8_t sw_is_pressed(uint8_t pin_mask) {
;uint8_t sw_new_state;
;   sw_new_state = inport_test_bits( pin_mask );
;	if ( sw_state == sw_new_state )
;		return 0;
;	sw_state = sw_new_state;
;   if ( sw_new_state == 0 )
;		return 0;
;	return 1;
;}
;---------------------------------------------------------------------------------	
; Rotina:    sw_is_pressed
; Descricao: 
; Entradas:  pins_mask
; Saidas:    devolve 1 se detecta uma transição 0 -> 1 no pino identificado em pin_mask 
;            e 0 se não detecta.   
; Efeitos:   
;---------------------------------------------------------------------------------	
sw_is_pressed:
	push	lr
	bl		inport_test_bits 
	; r0 = sw_new_state = inport_test_bits(pins_mask)
	ldr		r1, sw_state_address
	ldrb	r2, [r1, #0]	; r2 = sw_state
	cmp		r0, r2			; sw_state == sw_new_state
	beq		sw_is_pressed_0
	strb	r0, [r1, #0]	; sw_state = sw_new_state;
	sub		r0, r0, #0
	beq		sw_is_pressed_0
	mov		r0, #1
	b		sw_is_pressed_1
sw_is_pressed_0:
	mov		r0, #0
sw_is_pressed_1:
	pop		pc

sw_state_address:
	.word	sw_state

;---------------------------------------------------------------------------------	
;uint16_t inport_test_bits(uint16_t pins_mask) {
;	return ((inport_read() & pins_mask) == pins_mask);
;}
;---------------------------------------------------------------------------------	
; Rotina:    inport_test_bits
; Descricao: Devolve um se todos dos pinos do porto de entrada identificados com o valor um
; em pins_mask tomaremm o valor logico um , ou zero no caso contrario .
; Entradas:  Mascara com os bits a testar
; Saidas:    Devolve um ou zero conforme a descrição.
; Efeitos:   
;---------------------------------------------------------------------------------	
inport_test_bits:
	push	lr
	push	r4
	mov		r4, r0
	bl		inport_read
	and		r0, r0, r4
	cmp     r0, r4
	beq		end_inport_test_bit_1
	mov		r0, #0
	b		end_inport_test_bit
end_inport_test_bit_1:
	mov		r0, #1
end_inport_test_bit:
	pop		r4
	pop		pc
	
;---------------------------------------------------------------------------------	
;uint16_t inport_read() {
;	return [INPORT_ADDRESS];
;}
;---------------------------------------------------------------------------------	
; Rotina:    inport_read
; Descricao: Devolve o valor corrente do estado dos pinos do porto de entrada.
; Entradas:  
; Saidas:    Valor corrente do porto
; Efeitos:   
;---------------------------------------------------------------------------------	
inport_read:
	ldr		r0, inport_address_local
	ldrb	r0, [r0, #0]
	mov		pc, lr

inport_address_local:
	.word	INPORT_ADDRESS
;---------------------------------------------------------------------------------	
;uint8_t outport_init(uint8_t initial_value) {
;	outport_img = initial_value;
;	outport_write(outport_img);
;}
;---------------------------------------------------------------------------------	
; Rotina:    outport_init
; Descricao: Inicia o porto de saida, atribuindo-lhe o valor do argumento passado 
;			 a rotina.
; Entradas:  Valor para iniciar o porto de saida
; Saidas:    
; Efeitos:   Atualiza o valor da variavel imagem do porto
;---------------------------------------------------------------------------------	
outport_init:
	push	lr
	mov r0 , #0
	ldr		r1, outport_img_address
	strb	r0, [r1, #0]
	bl		outport_write
	pop		pc

;---------------------------------------------------------------------------------	
;void outport_set_bits(uint8_t pins_mask) {
;	outport_img |= pins_mask;
;	ourport_write(outport_img);
;}
;---------------------------------------------------------------------------------	
; Rotina:    outport_set_bits
; Descricao: Atribui o valor logico '1' aos pinos do porto de saida identificados 
;			 com o valor 1 no argumento passado a rotina. O estado dos restantes 
;			 bits nao e alterado.
; Entradas:  Mascara com os bits a alterar
; Saidas:    
; Efeitos:   Atualiza o valor da variavel imagem do porto
;---------------------------------------------------------------------------------	
outport_set_bits:
	push	lr
	ldr		r1, outport_img_address
	ldrb	r2, [r1, #0]
	orr		r0, r2, r0
	strb	r0, [r1, #0]
	bl		outport_write
	pop		pc

;---------------------------------------------------------------------------------	
;void outport_clear_bits(uint8_t pins_mask) {
;	outport_img &= ~pins_mask ;
;	ourport_write(outport_img);
;}
;---------------------------------------------------------------------------------	
; Rotina:    outport_clear_bits
; Descricao: Atribui o valor logico '0' aos pinos do porto de saida identificados 
;			 com o valor 1 no argumento passado a rotina. O estado dos restantes 
;			 bits nao e alterado.
; Entradas:  Mascara com os bits a alterar
; Saidas:    
; Efeitos:   Atualiza o valor da variavel imagem do porto
;---------------------------------------------------------------------------------	
outport_clear_bits:
	push	lr
	ldr		r1, outport_img_address
	ldrb	r2, [r1, #0]
	mvn		r0, r0
	and		r0, r2, r0
	strb	r0, [r1, #0]
	bl		outport_write
	pop		pc

;---------------------------------------------------------------------------------	
;void outport_write_bits(uint8_t pins_mask, uint8_t value) {
;	value &= pins_mask;
;	outport_img &= ~pins_mask;
;	outport_img |= value;
;	ourport_write(outport_img)
;}
;---------------------------------------------------------------------------------	
; Rotina:    outport_write_bits
; Descricao: Atribui aos pinos do porto de saida identificados com o valor lógico
;            um em pins_mask o valor dos bits correspondentes de value. O estado 
;            dos restantes bits nao e alterado.
; Entradas:  Mascara com os bits a alterar
;         :  valor dos bits a alterar  
; Saidas:    
; Efeitos:   Atualiza o valor da variavel imagem do porto
;---------------------------------------------------------------------------------	
outport_write_bits:
	push	lr
	and		r1, r0, r1				; r1 = pins_mask & value
	ldr		r2, outport_img_address
	ldrb	r3, [r2, #0]
	mvn		r0, r0					; ~pins_mask
	and		r3, r3, r0				; outport_img &= ~pins_mask;
	orr		r0, r3, r1				; outport_img |= pins_mask & value;
	strb	r0, [r2, #0]
	bl		outport_write
	pop		pc

;---------------------------------------------------------------------------------	
;void outport_write(uint8_t value) {
;	outport_img = value;
;	[OUTPORT_ADDRESS] = outport_img;
;}
;---------------------------------------------------------------------------------	
; Rotina:    outport_write
; Descricao: Atribui aos pinos do porto de saida o valor dos bits correspondentes de value.
; Entradas:  Valor a escrever no porto
; Saidas:    
; Efeitos:   Atualiza o valor da variavel imagem do porto
;---------------------------------------------------------------------------------	
outport_write:
	ldr		r1, outport_addr
	strb	r0, [r1, #0]
	mov		pc, lr

outport_img_address:
	.word	outport_img

outport_addr:
	.word	OUTPORT_ADDRESS
	
; Seccao:    .data
; Descricao: Guarda as variáveis globais com valor inicial definido
;
	.data
timer_level:
	.word	0
	
timer_1s:
	.word	0
	
timer_5s:
	.word	0
	
current_lvl_dificult_in_time:
	.word	10

score:
	.word	0
	
ticks:
	.word	0		; uint16_t ticks;
	
ball_pos:
	.byte	0x80
lvl_in_time:
	.byte	20, 10, 5		; 1s / 0.5s / 0.25s

new_point_led:
	.byte	0x00
	
direction: ; 0 away from player 1 into the player
	.byte	0x00
sw_state:
	.byte 	0
; Seccao:    .bss
; Descricao: Guarda as variáveis globais sem valor inicial definido
;
	.section .bss
outport_img:			; Imagem do porto de saida no programa
	.space	1	

; Seccao:    .stack
; Descricao: Implementa a pilha com o tamanho definido pelo simbolo STACK_SIZE
;
	.section .stack
	.space STACK_SIZE
tos:
	