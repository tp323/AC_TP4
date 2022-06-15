; Ficheiro:  p16_extint_demo.S
; Descricao: Programa para exemplificar o funcionamento do sistema de
;            interrupcoes do processador P16.
; Autor:     
; Data:      03-01-2022

; Definicao dos valores dos simbolos utilizados no programa
;
	.equ	STACK_SIZE, 64             ; Dimensao do stack (em bytes)

	.equ    INPORT_ADDRESS, 0xFF00  ; Endereço do porto de entrada da placa SDP16
	.equ	OUTPORT_ADDRESS, 0xFF00 ; Endereço do porto de saida da placa SDP16

	.equ	CPSR_BIT_I, 0x10          ; Mascara para a flag I do registo CPSR

	.equ	SYSCLK_FREQ, 0x5          ; Intervalo de contagem do circuito pTC
                                          ; que suporta a implementação do sysclk
										  ; fin_pTC = 10Hz fout_ptc=2Hz => T=500ms 
										  ; TMR = 10Hz/2Hz = 5
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
	.equ	BALL_LEDS_MASK, 0xfe
	.equ 	RAKET_MASK, 0x01
	.equ	VALU_OF_1S, 0xFF
	.equ	VALU_OF_25, 0xEF
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
	ldr		r0, ticks_addrb
	ldr		r1, [r0, #0]
	mov		r1,  #0
	str		r1, [r0, #0]
	mov r0, 0x80
	ldr r1, ball_pos_addr_ddd
	strb r0, [r1]
	
<<<<<<< Updated upstream
/* Constante relacioandas com a aplicacao. */	
	.equ	IE_FLAG, 			0x10
	.equ	OUTPORT_INITVALUE,	0x00
	.equ	LED_ON, 			1
	.equ	LED_OFF, 			0
	.equ	FIELD_MASK,			0xFE
	.equ	PLAYER_MASK,		0x80
	.equ	WALL_MASK,			0x02
	.equ	RAKET_MASK,			0x01
	.equ	LEVEL_MASK			0xC0
=======
	
	mov r0, #1
	mov r1, 0xE0
	bl timer_write		
	;bl timer_clearInterrupt	

>>>>>>> Stashed changes


	mov r0, IE_MASK

	msr cpsr, r0	
	pop pc	
	
ball_pos_addr_ddd:
	.word 	ball_pos	
	
ticks_addrb:
	.word ticks

main:
<<<<<<< Updated upstream
	push lr
	push r4 
	push r5
	push r6

init_game:	
	bl outport_init
	/* Inicializa o porto de saida e os valores necessarios ao inicio do jogo: posição, pontos e direção.
	score set score = 0*/
	mov r4, PLAYER_MASK // Ball current index0 
	mov r0, PLAYER_MASK	
	bl LED_set_on

	mov r5, #1			// Direction (1- UP, 0 - DOWN)
	mov r0, #0	
	bl set_score 		//score set score = 0

	mov r0, #50
	bl timer_init
	bl IRQ_enable
	
wait_for_init_stroke:	
	bl get_level
	mov r0, RAKET_MASK
	bl check_swing
	sub r0,r0,0
	bzs wait_for_init_stroke
	
start_game:
	
	bl init_countdowns
	bl move_ball
	
loop_game:
	bl count_point_check
	bl count_down_level_check

	bl is_player
	mov r1, #0
	cmp r0, r1
	beq loop_game

	bl check_swing
	cmp r0, r1
	beq loop_game


	mov r0, r4
	bl move_ball
	mov r4, r0
	bl check_position
	
	b loop_game

game_over:
	bl timer_stop
	pop r6
	pop r5
	pop r4
	pop pc


/* --------------------------------------------------------------------- AUXILIARY FUNCTIONS --------------------------------------------------------------------- */

get_level:
	push lr
	bl port_read
	mov r1, LEVEL_MASK
	and r0, r0, r1
	mov r1, #6
	lsr r0, r0, r1
	ldr r1, level_speed_addr
	ldr r0, [r1, r0]	// Level speed stored in r0
	ldr r1 current_speed_addr
	strb r0, [r1]
	pop pc

level_speed_addr:
	.level_speed

current_speed_addr:
	.current_speed

	.equ 	LED_NEW_POINT,		0x01
	//Assumindo 50ms (Utilizar clock de 1kHZ)
	.equ	POINT_TIME, 			20
	.equ	POINT_LED_TIME,		5
	.equ	LEVEL,				16 //TEMP

/*
	The point countdown will start with a the number of ticks required to score a point (1 second) plus the time
	for the LED to turn off. For each tick the variable will be decremented by one, once one second passes, a point
	will be scored and the LED turns on. The remaining time in the variable will correspond to the number of ticks
	the LED must remain active. Once it reaches zero, the LED turns off and the cycle restarts.
*/

//Initiates the countdown timer with the value passed as parameter.
//void init_timer_point(int value)
init_countdown_point:
	ldr r1, countdown_point_adrr
	str r0, [r1]
	mov pc, lr

//Decrements the variable by one
//void countdown_point_decrement()
countdown_point_decrement:
	mov r0, #1
	ldr r1, countdown_point_adrr
	ldr r2, [r1]
	sub r2, r2, r0
	str r2, [r1]
	mov pc, lr

//Checks the time of the countdown timer. If the remaining time is 250ms, activates de LED and scores a point. If it reaches
//zero turns off the LED and resets
//void count_point_check()
countdown_point_check:
=======
	push lr	
	bl timer_stop
	ldr r0, direction_addr_cc
	mov r1, 0
	strb r1, [r0]
	b main_while
	
direction_addr_cc:
	.word	direction
	
main_while:
	bl set_ball_leds
	
wait_for_init_stroke:
	mov r0, RAKET_MASK
	bl sw_is_pressed
	add r0,r0,0
	bzc start_game  
	b    wait_for_init_stroke
start_game:		
	bl timer_start
	bl init_timer_lvl
	bl init_timer_1s
	bl mov_ball
	bl set_ball_leds
game_loop:

	ldr r1, timer_1s_adrrvv
	ldr r0, [r1]
	bl sysclk_elapsed
	mov r1, VALU_OF_1S
	cmp r0, r1 ;20
	bhs one_second_pass_spik
	bl one_second_pass
one_second_pass_spik:	
	ldr r0, new_point_led_addr
	ldrb r0,[r0]
	sub r0,r0,0
	bzs time_lvl
	
	ldr r1, timer_1s_adrrvv
	ldr r0, [r1]
	bl sysclk_elapsed
	mov r1, VALU_OF_25
	cmp r0, r1 ;20
	blo	time_lvl	
	mov r0, 0
	bl set_led_newpoint
timer_1s_adrrvv:
	.word 	timer_1s	
time_lvl:	
	ldr r1, timer_level_adrr
	ldr r0, [r1]
	bl sysclk_elapsed
	mov r1, 0x0d ;TODO GET TIME OF LEVEL FROM A VAR-----------------
	cmp r0, r1 ;20	
	blo level_up_skip
	
	bl init_timer_lvl 
	ldr r0, ball_pos_addrb
	ldrb r0, [r0]
	mov r2, PLAYER_MASK
	sub r0, r0, r2
	bzc game_over_skip
	b game_over
game_over_skip:
	bl mov_ball
	bl set_ball_leds
	bl init_timer_lvl
	
level_up_skip:	
	;ball in wall ?
	ldr r0, ball_pos_addrb
	ldrb r0, [r0]
	;mov r2, WALL_MASK
	sub r0, r0, WALL_MASK
	bzc skip_invert_dir
	bl invert_dir
skip_invert_dir:
	;ball in player? 
	ldr r0, ball_pos_addrb
	ldrb r0, [r0]
	mov r2, PLAYER_MASK
	sub r0, r0, r2	
	bzc game_loop
	;raket? 
	mov r0, RAKET_MASK
	bl sw_is_pressed
	add r0,r0,0
	bzs  game_loop
	
	bl invert_dir
	bl init_timer_lvl	
	bl mov_ball
	bl set_ball_leds
	
	b game_loop
	
game_over:	
	bl invert_dir
	b  main_while 	
	
	
	
	
invert_dir:
	push lr
	ldr r0, direction_addr
	ldrb r1, [r0]
	mov r2, 1
	eor r1, r1, r2
	strb r1, [r0]
	pop pc
	
direction_addr:
	.word	direction
	
new_point_led_addr:
	.word 	new_point_led


	
	
		
score_addr:
	.word 	score
	
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
	
timer_level_adrr:
	.word timer_level

set_ball_leds:
	push lr	
	ldr	r1, ball_pos_addrb
	ldrb r1, [r1]
	mov r0, BALL_LEDS_MASK
	bl	outport_write_bits	
	pop pc
	
timer_1s_adrr:
	.word 	timer_1s	
	
ball_pos_addrb:
	.word 	ball_pos	
; set led new point to the valu of r0	
set_led_newpoint:
>>>>>>> Stashed changes
	push lr
	ldr r1, new_point_led_addrbbb
	strb r0, [r1]
	mov r1,r0
	mov r0, NEW_POINT_LED_MASK
	bl	outport_write_bits
	pop pc
new_point_led_addrbbb:
		.word	new_point_led

	
init_timer_1s:
	push lr
	bl sysclk_get_value	
	ldr r1, timer_1s_adrrb
	str r0, [r1]	
	pop pc
	
timer_1s_adrrb:
	.word 	timer_1s	
	
init_timer_lvl:
	push lr
	bl sysclk_get_value	
	ldr r1, timer_level_adrrb
	str r0, [r1]	
	pop pc
	
	

<<<<<<< Updated upstream
countdown_point_adrr:
	.word countdown_point

// ----------------------------------------------------------------
/*
	The level countdown will start with a the number of ticks required for each ball movement. Each tick will
	countdown the variable and once it reaches zero, the ball moves and the cycle restarts.
*/
	
//Initiates the countdown timer with the value passed as parameter.
//void init_timer_level(int value)
init_countdown_level:
	ldr r1, countdown_level_adrr
	str r0, [r1]
	mov pc, lr

//Decrements the variable by one
//void countdown_point_decrement()
countdown_level_decrement:
	mov r0, #1
	ldr r1, countdown_level_adrr
	ldr r2, [r1]
	sub r2, r2, r0
	str r2, [r1]
	mov pc, lr

//Checks if the countdown reached 0 and if it did, calls level_reached
//void count_down_level_check()
count_down_level_check:
	push lr
	ldr r1, countdown_level_adrr
	ldr r2, [r1]
	mov r0, #0
	cmp r0, r2
	beq level_reached
	pop pc
=======

timer_level_adrrb:
	.word timer_level
>>>>>>> Stashed changes




<<<<<<< Updated upstream
// ----------------------------------------------------------------		

init_countdowns:
	push lr
	mov r0, POINT_TIME
	bl init_countdown_point
	ldr r0, level_speed_addr
	ldr r0, [r0]
	bl init_countdown_level
	pop pc

//Updates the score variable in memory with the score passed as parameter
// void set_score(int score)
set_score:
	push lr
	ldr r1, score_addr
	str r0, [r1]
	pop pc
=======
>>>>>>> Stashed changes
	




<<<<<<< Updated upstream
//Checks if the position the ball is currently in is either the wall or the player
//void check_position(positionIndex)
check_position:
	push lr
	push r4

	mov r4, r0
	bl is_wall
	mov r1, #1
	cmp r0, r1
	beq	invert_direction

	mov r0, r4
	bl is_player
	mov r1, #1
	cmp r0, r1
	beq invert_direction

	pop r4
=======
ball_pos_addr:
	.word 	ball_pos
	

	
add_score:	
	ldr r0, score_addr_bb
	ldr r1, [r0]
	add r1, r1, 1
	str r1, [r0]
	mov pc, lr
	
score_addr_bb:
	.word score
;-------------------------------------------------------------------------
; Rotina:    mov_ball
; Descricao: R
; Entradas:  -
; Saidas:    -
; Efeitos:   
; void mov_ball() {
;   
;}	
mov_ball:
	push lr
	ldr r0, ball_pos_addr_cc
	ldrb r0, [r0]	
	ldr r1, direction_addr_bb
	ldrb r1, [r1]
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
	ldr r1, ball_pos_addr_cc
	strb r0, [r1]
	
>>>>>>> Stashed changes
	pop pc
	
	
direction_addr_bb:
	.word direction
	
ball_pos_addr_cc:
		.word ball_pos

<<<<<<< Updated upstream
//Check if the current position it the wall
//boolean is_player(currentIndex)
is_player:
	mov r1, PLAYER_MASK
	cmp r0, r1
	beq player_found
	mov r0, #0
	mov pc lr

player_found:
	mov r0, #1
	mov pc, lr


//Check if the current position it the player
//boolean is_wall(currentIndex)
is_wall:
	mov r1, WALL_MASK
	cmp r0, r1
	beq wall_found
	mov r0, #0
	mov pc lr

wall_found:
	mov r0, #1
	mov pc, lr


//Switches direction
//void invert_direction()
invert_direction:
	mov r0, #1
	eor r5, r5, r0
	mov pc lr
	
	
/* Acende o led no índice idx do porto de saída.
void LED_set_on(uint8_t idx);
*/
LED_set_on:
	push	lr
	mov		r1, LED_ON
	bl		port_write_bit
	pop		pc
=======
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
	ldr		r0, ticks_addr
	ldr		r1, [r0, #0]
	add		r1, r1, #1
	str		r1, [r0, #0]
	; clear Interrupt Request
	;bl 	timer_clearInterrupt
	mov r1, 0xFF
	ldr  r0, ptc_addr
	strb r1, [ r0, #pTC_TIR ]
	;bl timer_write	
	; Epilogo
	pop		r2
	pop		r1
	pop		r0
	movs	pc, lr
	
>>>>>>> Stashed changes

	
timer_clearInterrupt:
	mov r0, 0
	ldr r1, timer_addressr
	strb r0, [ r1, #pTC_TIR ]
	mov pc, lr
	
timer_addressr:
	.word  pTC_ADDRESS	
;-------------------------------------------------------------------------
;Funcao para devolver o valor corrente da variável global ticks.
;uint16_t sysclk_get_value ( void );
;	return ticks;
;-------------------------------------------------------------------------
sysclk_get_value:
	ldr		r1, ticks_addr
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
	ldr	 r1, ticks_addr
	ldr  r2, [r1, #0] 	; r0 = ticks
	sub  r0, r2, r0
	mov  pc,lr

ticks_addr:
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
	ldr 	r2, timer_addressrc
	add		r0, r0, r0
	strb 	r1, [r2,r0]	
	mov		pc,lr

timer_addressrc:
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

<<<<<<< Updated upstream

//------------------------------------------------ SUBSTITUIR PELA FORNECIDA NAS AULAS
//Checks if there was a transiction from 0 to 1
//boolean check_swing()
check_swing:
	push lr
	mov r0, sw_state_address
	ldr r0, [r0]
	mov r1, #0
	cmp r0, r1	//checking if the last recorded position is racket down
	bne no_swing

	mov r1, 0x0F
	mov r2, #0
	bl port_read_bit
	mov r1, #0
	cmp r0, r1
	bne swing

no_swing:
	mov r0 #0

swing:
	mov r1, sw_state_address
	strb r0, [r1]
	pop pc
//------------------------------------------------
=======
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
>>>>>>> Stashed changes

sw_state_address:
	.word	sw_state

<<<<<<< Updated upstream
/* Interrupt Service Routine */
isr:
	push lr
	bl countdown_point_decrement
	bl countdown_level_decrement
	pop lr
	movs	pc, lr; PC = LR; CPSR = SPSR
=======
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
>>>>>>> Stashed changes
	
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
	ldrb		r0, [r0, #0]
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
	
current_lvl_dificult_in_time:
	.word	20 
	
score:
	.word	0
<<<<<<< Updated upstream
current_speed:
	.word 0
level_speed:
	.byte 12, 6, 3
racket_position:
	.byte 0
port_img:
	.space	1
=======
	
ticks:
	.word	0		; uint16_t ticks;
	
ball_pos:
	.byte	0x80
	
new_point_led:
	.byte	0x00
	
direction: ; 0 away from player 1 into the player
	.byte	0x00
>>>>>>> Stashed changes
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
	