# UVM AXI GPIO/SPI SoC Verification

## 프로젝트 개요

**발표자료: https://drive.google.com/file/d/1Z_oX86YITDtkyCXpNJuF5DB1RtBm6dTk/view?usp=drive_link**  
본 프로젝트는 AXI-Lite 기반 SPI/GPIO SoC 환경을 구현하고, UVM 기반 검증 환경으로 동작을 확인한 프로젝트입니다. 설계는 AXI-Lite register access가 GPIO 제어, SPI Master packet 전송, SPI Slave 수신, LED/FND Display 출력 갱신으로 이어지는 구조로 구성했습니다.

구현 구조에서는 MicroBlaze C 코드가 memory-mapped register를 제어하도록 구성했으며, UVM 검증에서는 실제 MicroBlaze 실행을 포함하지 않고 AXI BFM으로 register read/write transaction을 생성해 CPU 접근을 대체했습니다. 이를 통해 CPU 실행 계층과 peripheral 검증 범위를 분리하고, register access 이후 GPIO 및 SPI 경로가 기대한 흐름대로 동작하는지 확인했습니다.

검증은 개별 모듈 출력만 확인하는 방식이 아니라, 데이터가 이동하는 경로 기준으로 구성했습니다. GPIO read/write path, SPI packet transfer path, SPI Display update path를 나누어 monitor와 scoreboard로 비교했으며, AXI-Lite transaction으로 입력한 packet이 SPI Master, SPI Slave, Display manager를 거쳐 LED/FND 출력으로 반영되는지 확인했습니다.

Functional coverage에서는 constrained random packet 검증 결과를 단순 pass/fail로만 보지 않고, coverage 결과를 정량적으로 해석했습니다. packet field별 coverpoint를 정의하고, random test 반복 횟수에 따라 예상되는 missing bin 개수를 계산한 뒤 실제 coverage report와 비교했습니다. 이를 통해 random 검증에서는 테스트를 많이 실행하는 것뿐 아니라, 검증 공간과 반복 횟수의 관계를 이해하고 coverage 결과를 해석하는 과정이 중요하다는 점을 확인했습니다.

## 목표 동작

- AXI-Lite write/read 흐름으로 GPIO IP register 동작을 검증합니다.
- GPIO output pin 변화가 register write와 일치하는지 확인합니다.
- SPI 전송 결과를 scoreboard에서 비교합니다.
- GPIO와 SPI 검증 환경을 각각 구성하고 test top에서 실행합니다.

## 기술 스택

| 구분 | 내용 |
| --- | --- |
| 핵심 개념 | UVM, AXI4-Lite, GPIO register, SPI, scoreboard, interface, smoke test |
| 검증 대상 | GPIO8 AXI IP, SPI Master IP, SPI Slave/mirror path |
| 사용 언어 | Verilog, SystemVerilog |
| 사용 도구 | UVM 1.2 기반 simulator, Verdi/파형 디버깅 환경 |

## 시스템 구조

~~~text
tb_gpio_uvm_top
├─ GPIO8_v1_0
├─ axi_lite_if
├─ gpio_pin_if
└─ gpio_uvm_test
   └─ gpio_env
      └─ gpio_scoreboard

tb_spi_uvm_top
├─ spi_master_v1_0
├─ spi_slave
├─ spi_line_if
├─ spi_result_if
└─ spi_mirror_uvm_test
   └─ spi_env
      └─ spi_scoreboard
~~~

- axi_lite_if: AXI-Lite bus 신호를 testbench interface로 묶습니다.
- gpio_pin_if: GPIO pin 관찰용 interface입니다.
- spi_line_if: SPI line 관찰 및 구동용 interface입니다.
- soc_uvm_pkg: GPIO/SPI scoreboard, env, test class를 포함합니다.
- tb_gpio_uvm_top: GPIO AXI IP 검증 top입니다.
- tb_spi_uvm_top: SPI mirror path 검증 top입니다.

## 검증 방식

- AXI-Lite register write/read 결과와 GPIO pin 변화를 비교합니다.
- SPI line transaction과 slave 결과를 scoreboard에서 확인합니다.
