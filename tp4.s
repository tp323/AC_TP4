	.section .startup
	b		_start
	ldr		pc, addr_isr
_start:
	ldr		sp, addr_stack_top
	mov		r0, pc
	add		lr, r0, 4
	ldr		pc, addr_main
	b		.	
addr_stack_top:
	.word	stack_top
addr_main:
	.word 	main
addr_isr:
	.word	isr
	

	
/* Constante relacioandas com a aplicacao. */	
	.equ	IE_FLAG, 			0x10
	.equ	OUTPORT_INITVALUE,	0x80
	.equ	LED_ON, 			1
	.equ	LED_OFF, 			0
	.equ	FIELD_MASK,			0xFE
	.equ	PLAYER_MASK,		0x80
	.equ	WALL_MASK,			0x02
	.equ	RAKET_MASK,			0x01


	.text
 
main:
	push lr
	push r4 
	push r5
	push r6
	
	bl outport_init
	/* Inicializa o porto de saida e os valores necessarios ao inicio do jogo: posição, pontos e direção.
	score set score = 0*/
	mov r4, PLAYER_MASK // Ball current index0 
	mov r5, #1			// Direction (1- UP, 0 - DOWN)
	mov r0, #0	
	bl set_score 		//score set score = 0
	bl IRQ_enable
	
	mov r0, PLAYER_MASK	
	bl LED_set_on
	
wait_for_init_stroke:	
	mov r0, RAKET_MASK
	bl sw_is_pressed
	sub r0,r0,0
	bzs wait_for_init_stroke
	
start_game:
	//bl timer_init	
	
	bl init_timer_1s
	bl init_timer_lvl
	bl move_ball
	
loop_game:
	bl led_new_point_handler

	ldr r0, timer_level_adrr
	bl timer_elapsed
	mov r1, valor_do_tempo_por_transicao_level
	cmp r0, r1
	bhs move_ball
	
	bl check_position
	
	b loop_game
	pop r6
	pop r5
	pop r4
	pop pc


led_new_point_handler:
	push lr
	mov	r1, valor_de_um_segundo
	lsr r2, r1, #2	//avoid using another var for valor_de_um_.250seg by doing 1s/4=.250s
	bl timer_elapsed

	//if higher than .25s turn led_off
	cmp r0, r2
	bhs led_new_point_off
	//if higher than 1s  turn led_on
	cmp r0, r1
	bhs led_new_point_on
	pop pc
	
	
one_second_pass:
	push lr	
	
	
	bl init_timer_1s	//restart timer
	
	
	bl led_new_point_on	
	
	pop lr

	
led_new_point_on:
	push lr
	mov r0, #1
	ldr r1, led_new_point_state_addr
	strb r0, [r1]	
	mov r0, LED_NEW_POINT	
	bl LED_set_on	
	pop lr

	
led_new_point_off:
	push lr
	mov r0, LED_NEW_POINT	
	bl LED_set_off
	mov r0, LED_OFF
	ldr r1, led_new_point_state_addr
	strb r0, [r1]
	pop pc

time_level_passed:	
	push lr
	
	
	mov r1, PLAYER_MASK
	cmp r1, r4 //TODO ALTERAR PARA VAR DE POSIÇÃO
	bhs game_over
	bl move_ball
	bl init_timer_lvl
	
	pop pc

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
	push lr
	ldr r1, countdown_point_adrr
	ldr r1, [r1]

	mov r0, POINT_LED_TIME
	sub POINT_TIME, POINT_LED_TIME
	cmp r1, r0
	beq point_LED_OFF

	mov r0, #0
	cmp r0, r1
	beq point_scored
	
	pop pc

//Increments the point variable, turns off th LED and resets
//void point_scored()
point_scored:
	bl get_score
	add r0, r0, #1	
	bl set_score
	bl point_LED_OFF
	mov r0, POINT_TIME
	bl init_countdown_level

//Turns on the Point LED
//void point_LED_ON()
point_LED_ON:
	push lr
	mov r0, #0
	bl LED_set_on
	pop pc

//Turns on the Point LED
//void point_LED_OFF()
point_LED_OFF:
	push lr
	mov r0, #0
	bl LED_set_off
	pop pc

countdown_point_adrr:
	.word countdown_point
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
/*countdown_point_decrement:
	mov r0, #1
	ldr r1, countdown_level_adrr
	ldr r2, [r1]
	sub r2, r2, r0
	str r2, [r1]
	mov pc, lr*/

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

//Resets the countdown and moves ball
//level_reached()
level_reached:
	push lr
	mov r0, LEVEL
	bl init_countdown_level
	bl move_ball
	pop pc


countdown_level_adrr:
	.word countdown_level

//Updates the score variable in memory with the score passed as parameter
// void set_score(int score)
set_score:
	push lr
	ldr r1, score_addr
	str r0, [r1]
	pop pc
	
//Returns the value of the variable score saved in memory
// int get_score()	
get_score:
	push lr
	ldr r1, score_addr
	ldr r0, [r1]
	pop pc
		
score_addr:
	.word 	score	
led_new_point_state_addr:
	.word 	led_new_point_state		


//Move the ball one position on the current direction. Returns new position index
// int move_ball(positionIndex)
move_ball:
	push lr
	mov r1, #0
	cmp r0, r1
	beq mov_down
	b mov_up	
	pop pc

//Moves the ball one position up, and returns the new position index
//int mov_up(positionIndex)
mov_up:
	push lr
	lsr r0, r0, #1
	mov r2, r0
	mov r1, FIELD_MASK
	mov r0, #1
	bl port_write_bit_range
	pop pc

//Moves the ball one position down, and returns the new position index
//int mov_down(positionIndex)
mov_down:
	push lr
	lsl r0, r0, #1
	mov r2, r0
	mov r1, FIELD_MASK
	mov r0, #1
	bl port_write_bit_range
	pop pc

//Checks if the position the ball is currently in is either the wall or the player
//void check_position(positionIndex)
check_position:
	push lr
	mov r1, WALL_MASK
	cmp r1, r0
	beq is_wall_position
	
	mov r1, PLAYER_MASK
	cmp r1, r0
	beq is_player_position

	pop pc


//Switches direction and awaits for raket swing
//void is_player_position()
is_player_position:
	push lr
	mov r5, #1
	mov r0, RAKET_MASK
	bl sw_is_pressed
	mov r1, #1
	cmp r0, r1
	beq inverte_ball	
	mov r0, #1
	pop pc

//Switches the direction of the ball
//void is_wall_position()
is_wall_position:
	mov r5, #0
	mov pc, lr
	
/* --------------------------------------------------------------------- AUXILIARY FUNCTIONS --------------------------------------------------------------------- */
/* Acende o led no índice idx do porto de saída.
void LED_set_on(uint8_t idx);
*/
LED_set_on:
	push	lr
	mov		r1, LED_ON
	bl		port_write_bit
	pop		pc

/* Apaga o led no índice idx do porto de saída.
void LED_set_off(uint8_t idx);
*/
LED_set_off:
	push	lr
	mov		r1, LED_OFF
	bl		port_write_bit
	pop		pc
	
/* Inicia o porto de saída com o valor v.
void outport_init(uint8_t v);
*/
outport_init:
	push	lr
	mov		r0, OUTPORT_INITVALUE
	bl		port_write
	pop		pc
	
/* Ativa o atendimento de interrupções externas. Mantém as restantes flags.
void IRQ_enable();
*/	
IRQ_enable:
	mrs		r0, cpsr
	mov		r1, #IE_FLAG
	orr		r0, r0, r1
	msr		cpsr, r0
	mov		pc, lr
/* Inibe o atendimento de interrupções externas. Mantém as restantes flags.
void IRQ_disable();
*/	
IRQ_disable:
	mrs		r0, cpsr
	mov		r1, #IE_FLAG
	mvn		r1, r1
	and		r0, r0, r1
	msr		cpsr, r0
	mov		pc, lr
		
;----------------------------------------------------------------
; API relacionada com o temporizador PicoTimer/Counter
;----------------------------------------------------------------
/* Constantes relacionada com o temporizador PicoTimer/Counter */	
	.equ pTC_ADDRESS, 		0xFF40
	.equ pTC_TCR, 			0
	.equ pTC_TMR, 			2
	.equ pTC_TC, 			4
	.equ pTC_NTIR,			6
	.equ pTC_CMD_START, 	0
	.equ pTC_CMD_STOP, 	1
	
/* Funcao para fazer a iniciacao do periferico
para habilitar o funcionamento em modo
continuo e com intervalo de contagem
interval ticks . 
void timer_init ( uint8_t interval );
*/	
timer_init:
	push 	lr
	push 	r0
	; Parar contagem
	bl 		timer_stop
	; Programar intervalo de contagem
	pop 	r0
	ldr 	r1, ptc_address
	strb 	r0, [r1, pTC_TMR]
	; Reiniciar contagem
	bl 		timer_start
	pop 	pc
	
/* Funcao para devolver o valor corrente da
contagem do periferico .
uint8_t timer_get_value ( void );
*/
timer_get_value:
	ldr 	r1, ptc_address
	ldrb 	r0, [r1, #pTC_TC]
	mov 	pc, lr

/* Funcao para devolver o tempo decorrido desde
o instante last_read . O tempo e medido em
unidades de contagem ( ticks ). 
uint8_t timer_elapsed ( uint8_t last_read );
*/
timer_elapsed:
	push 	lr
	push 	r0
	bl 		timer_get_value
	pop 	r1
	sub 	r0, r0, r1
	pop 	pc

/* Funcao para iniciar a contagem no periferico .
void timer_start ( void );
*/
timer_start:
	mov 	r0, #pTC_CMD_START
	ldr 	r1, ptc_address
	strb 	r0, [r1, #pTC_TCR ]
	mov 	pc, lr

/* Funcao para parar a contagem no periferico . A
paragem da contagem faz clear a contagem .
void timer_stop ( void );
*/	
timer_stop:
	mov 	r0, #pTC_CMD_STOP
	ldr 	r1, ptc_address
	strb 	r0, [r1, #pTC_TCR ]
	mov 	pc, lr
	
timer_clr_irq:
	;ToDo
	
ptc_address:
	.word 	pTC_ADDRESS

;----------------------------------------------------------------
; API relacionada com portos paralelos (entrada e saída)
;----------------------------------------------------------------
	.equ PORT_ADDRESS, 0xFF00
/* Retorna o valor presente á entrada do porto de entrada 
uint8_t port_read();
*/
port_read:
	ldr		r0, addr_port
	ldrb	r0, [r0]
	mov		pc, lr

/* Escreve o byte recebido por parâmetro no porto de saída
void port_write(uint8_t v);
*/
port_write:
	ldr		r1, addr_port
	strb	r0, [r1]
	ldr		r1, addr_port_img
	strb	r0, [r1]
	mov		pc, lr

/* Retorna o valor do bit no índice idx da palavra v.
   A função retorna o valor 1 ou 0.
uint8_t port_read_bit(uint8_t v, uint8_t idx);
*/
port_read_bit:
	push	lr
	bl		lsr_r_r
	mov		r1, 1
	and		r0, r0, r1
	pop		pc


/* Atualiza no porto de saída o valor do bit no índice idx com o valor v.
   Os restantes bits permanecem inalterados.
void port_write_bit(uint8_t idx, uint8_t v);
*/
port_write_bit:
	push	lr
	mov		r2, r1
	mov		r1, 1
	bl		port_write_bit_range
	pop		pc


/* Atualiza no porto de sa�da o valor dos bits correspondente ao intervalo
   definido por idx e msk com o valor v.
   Os restantes bits permanecem inalterados.
void port_write_bit_range(uint8_t idx, uint8_t msk, uint8_t v);
*/
port_write_bit_range:
	push	lr
	push	r4
	push	r2 		; preserva o valor v no topo do stack
	; lsl	msk, idx
	eor		r0, r0, r1
	eor		r1, r0, r1
	eor		r0, r0, r1
	mov		r4, r1  ; R4 = idx
	bl		lsl_r_r
	; lsl	v, idx
	mov		r1, r4
	mov		r4, r0	; R4 = msk << idx
	pop		r0		; recupera o valor v do topo do stack
	bl		lsl_r_r
	mvn		r4, r4
	ldr		r1, addr_port_img
	ldrb	r1, [r1]
	and		r1, r1, r4
	orr		r0, r1, r0
	bl		port_write
	pop		r4
	pop		pc

addr_port:
	.word	PORT_ADDRESS
addr_port_img:
	.word	port_img

;----------------------------------------------------------------
; Fun��es auxiliares que retornam os resultados do deslocamento 
; de lsl rx, ry e lsr rx, ry
;----------------------------------------------------------------
/* Deslocamento para a direita de x, y bits (y entre 0 e 7).
uint8_t lsr_r_r(uint8_t x, uint8_t y);
*/
lsr_r_r:
	lsl		r1, r1, 2
	add		pc, r1, pc
	lsr		r0, r0, 0
	mov		pc, lr
	lsr		r0, r0, 1
	mov		pc, lr
	lsr		r0, r0, 2
	mov		pc, lr
	lsr		r0, r0, 3
	mov		pc, lr
	lsr		r0, r0, 4
	mov		pc, lr
	lsr		r0, r0, 5
	mov		pc, lr
	lsr		r0, r0, 6
	mov		pc, lr
	lsr		r0, r0, 7
	mov		pc, lr
/* Deslocamento para a esquerda de x, y bits (y entre 0 e 7).
uint8_t lsl_r_r(uint8_t x, uint8_t y);
*/
lsl_r_r:
	lsl		r1, r1, 2
	add		pc, r1, pc
	lsl		r0, r0, 0
	mov		pc, lr
	lsl		r0, r0, 1
	mov		pc, lr
	lsl		r0, r0, 2
	mov		pc, lr
	lsl		r0, r0, 3
	mov		pc, lr
	lsl		r0, r0, 4
	mov		pc, lr
	lsl		r0, r0, 5
	mov		pc, lr
	lsl		r0, r0, 6
	mov		pc, lr
	lsl		r0, r0, 7
	mov		pc, lr

;----------------------------------------------------------------
; API relacionada com o relógio de sistema
;----------------------------------------------------------------
/* Inicia o relógio de sistema com o valor init_value.
uint16_t sys_clock_init(uint16_t init_value);
*/
sys_clock_init:
	ldr		r1, addr_sys_clock
	str		r0, [r1]
	mov		pc, lr
	
/* Retorna o valor atual do relógio de sistema.
uint16_t sys_clock_get_time();
*/
sys_clock_get_time:
	ldr		r0, addr_sys_clock
	ldr		r0, [r0]
	mov		pc, lr

/* Retorna o tempo decorrido desde time_ref até ao valor atual 
   do relógio de sistema.
uint16_t sys_clock_elapsed_time(uint16_t time_ref);
*/
sys_clock_elapsed_time:
	push	lr
	push	r0
	bl		sys_clock_get_time
	pop		r1
	sub		r0, r0, r1
	pop		pc

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
; Saidas:    devolve 1 se detecta uma transicao 0 -> 1 no pino identificado em pin_mask 
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
	

/* Interrupt Service Routine */
isr:
	movs	pc, lr; PC = LR; CPSR = SPSR
	

	.data
countdown_level:
	.word	0
countdown_point:
	.word	0
score:
	.word	0
sys_clock:
	.word	0
port_img:
	.space	1
sw_state:
	.byte 	0
led_new_point_state:
	.byte 	0

addr_sys_clock:
	.word	sys_clock

	.section .stack
	.space 1024
stack_top:





