##Lab 4 -- Interrupts
##by Joshua Cohen
##Version: 1.1 > 4.27.21
#Interrupt vectors:
#0-3 active
#reg map: $t9 = stop val; $s0, $s1 for int vectors
.data
vector:.ascii "#cev" #reserve 4 bytes
header: .asciiz "Lab 4: Interrupts by Joshua C\n"
.align 2
prompt1: .asciiz "Enter Int TYPE: 0=NMI, 1=NVI, 2=VI, 9=Halt"
.align 2
prompt2: .asciiz "Enter Int Vector (0-15):"
.align 2
NMI_str: .asciiz "NMI interrupt!"
NVI_str: .asciiz "NVI interrupt!"
VI_str: .asciiz " VI interrupt!"
Vect_str: .asciiz "Vector="
.align 2
Err_msg1: .asciiz "Error: illegal Int Type"
.align 2
Err_msg2: .asciiz "Error: illegal entry"
.align 2
Halt_msg: .asciiz "Halted! Good-bye"
.align 2
Stop_msg: .asciiz "Stopped out!"
.align 2
end_data: .asciiz "$***$***"
#define
.eqv heap, 0x10040000
.eqv in_buf, 0x10040020 #input buffer
.eqv exc_seg, 0x80000180
.eqv stop,10
#macros
.macro done
li $v0, 10 #stop code
syscall #stop
.end_macro
.macro print_mac (%str)
la $a0, %str
li $v0, 4
syscall
.end_macro 
.macro msgbox (%str)
la $a0, %str
li $v0, 55 #GUI msg code
li $a1, 1 #msg type is info 
syscall 
.end_macro 

#**ISR macro-> Trap
.macro _ISR (%str)
la $a0, %str
#jal printStr
jal GUI_out
Teq $0,$0 #Trap: simulate INT<-1 (in ktext)
b loop_main
.end_macro 
#code 
.text
#saves:
#$t9
li $t9, stop
La $a0, header
Jal printStr
#main Loop
loop_main:
subiu $t9,$t9,1 #decrement counter
blez $t9, Stop
la $a0,prompt1
Jal GUI_in #get Type in $a0
move $s0, $a0
#Int TYPE Branch table (if-case)
beq $a0,0,NMI
beq $a0,1,NVI
beq $a0,2,VI
beq $a0,9,Halt
b Err #none of above
NMI: _ISR(NMI_str)

NVI: _ISR(NVI_str)
VI: #get vector
	la $a0,prompt2
	Jal GUI_in #get vector in $a0
	move $s1, $a0 #save vector in $s1
	_ISR(VI_str)
Halt:  #Quit
	la $a0, Halt_msg
	jal GUI_out
	jal printStr
	done #**exit program**
Err:  la $a0,Err_msg1 #default	
	jal GUI_out
	b loop_main
Stop: la $a0, Stop_msg
	jal printStr
	done  #**alt exit-stopped out 
#end table
#--END MAIN LOOP--
##subroutines follow
#print $a0 on console
printStr:
	li $v0,4
	syscall 
	jr $ra
#OUTPUT GUI MSG
GUI_out: #ptr in $a0
	li $v0, 55 #GUI msg code
	li $a1, 1 #msg type is info
	syscall
	jr $ra
#INPUT GUI MSG
GUI_in:  #a0=int, $a1=status code
	li $v0, 51 #int read
	syscall
	bltz, $a1, in_error
	jr $ra
in_error:
	msgbox(Err_msg2)
	li $a0, 5
	jr $ra
#--end subs--		
##**start handler code in kernel seg**
.macro push_k
move $k0, $a0 #save registers
move $k1, $a1
.end_macro 
.macro pop_k
move $a0, $k0 #restore registers
move $a1, $k1
.end_macro 
.macro _print %str
la $a0, %str
jal print_str
b return	
.end_macro	
#Begin Kernel code
.kdata
kmsg: .asciiz "starting Interrupt handler for: "
def_msg: .asciiz "error: unimplemented vector\n"
.align 2
newLn: .asciiz "\n"
.align 2
end_Kdata: .asciiz "ENDkDATA$$$$"
ioDevice1: .asciiz " Keyboard"
ioDevice2: .asciiz " Mouse"
ioDevice3: .asciiz " Phone"
ioDevice4: .asciiz " Speaker"
.ktext exc_seg
#save state
push_k
li $v0, 4
syscall
print_mac kmsg #prt msg via macro
mfc0 $t0, $14 #EPC
addi $t0,$t0, 4 #incrementing RA in EPC
mtc0 $t0,$14 #EPC+4 (for ERET)
#saves: $s0=int code, $s1=vector  $s5=pointer to iodevices
#--INT Branch Table
Beq $s0, 0, NMI_Handler
Beq $s0, 1, NVI_Handler
#else VI
#--Branch Table--
Beq $s1, 0, v0
Beq $s1, 1, v1
Beq $s1, 2, v2
Beq $s1, 3, v3
#default
b def
#end Br table 
#start ISR's
NMI_Handler:
_print NMI_str
NVI_Handler:
_print NVI_str
#--Vector Table--
v0: 
	
	la $s5, ioDevice1 
	b finish#ioDevice1
v1: 
	la $s5, ioDevice2
	b finish#ioDevice2
v2: 
	la $s5, ioDevice3
	b finish#ioDevice3
v3: 
	la $s5, ioDevice4
	b finish#ioDevice4
def: #un-impl
	print_mac def_msg
	eret
finish: 
	print_mac Vect_str
	move $a0, $s1 #set vector
	jal print_val 
	la $a0,($s5) #set IO device
	jal print_io
b return 
#end Tabledef: #un-impl
print_mac def_msg
return:
	pop_k
	eret
#end---ISR's---
#subs
print_io:  #sub for printing corresponding io device
	   jal print_strNFT
	   jal newline
	   b return
print_strNFT: #$a0 = string ptr
	li $v0, 4
	syscall
	jr $ra
print_str: #$a0= string ptr
	li $v0, 4
	syscall
	b newline
print_val: #$a0=val
	li $v0, 1
	syscall
	#fall thru
newline: 
	li $v0, 4
	la $a0, newLn #"\n"
	syscall 
	jr $ra
#fall through
#delay loop--
jal delay
pop_k
####
delay:
	subu $a0, $a0, 10
	bgtz $a0, delay
	jr $ra
#end of program--#



	
	

