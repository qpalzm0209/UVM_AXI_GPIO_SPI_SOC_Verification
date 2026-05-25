# UVM AXI GPIO/SPI SoC Verification

## 프로젝트 개요

Custom AXI GPIO IP와 SPI 관련 모듈을 UVM 기반으로 검증한 SoC 검증 프로젝트입니다.
AXI-Lite register 접근, GPIO 출력, SPI mirror 동작을 testbench에서 확인합니다.

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

```text
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
```

- `axi_lite_if`: AXI-Lite bus 신호를 testbench interface로 묶습니다.
- `gpio_pin_if`: GPIO pin 관찰용 interface입니다.
- `spi_line_if`: SPI line 관찰 및 구동용 interface입니다.
- `soc_uvm_pkg`: GPIO/SPI scoreboard, env, test class를 포함합니다.
- `tb_gpio_uvm_top`: GPIO AXI IP 검증 top입니다.
- `tb_spi_uvm_top`: SPI mirror path 검증 top입니다.

## 검증 방식

- AXI-Lite register write/read 결과와 GPIO pin 변화를 비교합니다.
- SPI line transaction과 slave 결과를 scoreboard에서 확인합니다.
