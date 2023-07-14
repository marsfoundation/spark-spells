## Reserve changes

### Reserve altered

#### DAI ([0x6B175474E89094C44Da98b954EedeAC495271d0F](https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F))

| description | value before | value after |
| --- | --- | --- |
| ltv | 74 % | 0.01 % |
| liquidationThreshold | 76 % | 0.01 % |
| interestRateStrategy | [0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d](https://etherscan.io/address/0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d) | [0x191E97623B1733369290ee5d018d0B068bc0400D](https://etherscan.io/address/0x191E97623B1733369290ee5d018d0B068bc0400D) |
| interestRate | ![before](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) | ![after](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) |

#### sDAI ([0x83F20F44975D03b1b09e64809B757c47f942BEeA](https://etherscan.io/address/0x83F20F44975D03b1b09e64809B757c47f942BEeA))

| description | value before | value after |
| --- | --- | --- |
| oracleLatestAnswer | 102,556,385 | 102,557,375 |


#### WETH ([0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2](https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2))

| description | value before | value after |
| --- | --- | --- |
| reserveFactor | 15 % | 5 % |
| interestRateStrategy | [0x764b4AB9bCA18eB633d92368F725765Ebb8f047C](https://etherscan.io/address/0x764b4AB9bCA18eB633d92368F725765Ebb8f047C) | [0x36e9A9e26713fb45EB957609Ebb0fa37d9114d28](https://etherscan.io/address/0x36e9A9e26713fb45EB957609Ebb0fa37d9114d28) |
| variableRateSlope1 | 3.8 % | 4 % |
| baseStableBorrowRate | 3.8 % | 4 % |
| interestRate | ![before](/.assets/6747e3b5adc7a63d169daf26756fbbc8cc8e1802.svg) | ![after](/.assets/939b8b736db42cc5a1ecb3f1c1bc54abe66f9f67.svg) |

## Raw diff

```json
{
  "reserves": {
    "0x6B175474E89094C44Da98b954EedeAC495271d0F": {
      "interestRateStrategy": {
        "from": "0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d",
        "to": "0x191E97623B1733369290ee5d018d0B068bc0400D"
      },
      "liquidationThreshold": {
        "from": 7600,
        "to": 1
      },
      "ltv": {
        "from": 7400,
        "to": 1
      }
    },
    "0x83F20F44975D03b1b09e64809B757c47f942BEeA": {
      "oracleLatestAnswer": {
        "from": 102556385,
        "to": 102557375
      }
    },
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": {
      "interestRateStrategy": {
        "from": "0x764b4AB9bCA18eB633d92368F725765Ebb8f047C",
        "to": "0x36e9A9e26713fb45EB957609Ebb0fa37d9114d28"
      },
      "reserveFactor": {
        "from": 1500,
        "to": 500
      }
    }
  },
  "strategies": {
    "0x191E97623B1733369290ee5d018d0B068bc0400D": {
      "from": null,
      "to": {
        "baseRateConversion": "1000000000000000000000000000",
        "borrowSpread": 0,
        "maxRate": "750000000000000000000000000",
        "performanceBonus": 0,
        "supplySpread": 0
      }
    },
    "0x36e9A9e26713fb45EB957609Ebb0fa37d9114d28": {
      "from": null,
      "to": {
        "baseStableBorrowRate": "40000000000000000000000000",
        "baseVariableBorrowRate": "10000000000000000000000000",
        "maxExcessStableToTotalDebtRatio": "1000000000000000000000000000",
        "maxExcessUsageRatio": "200000000000000000000000000",
        "optimalStableToTotalDebtRatio": 0,
        "optimalUsageRatio": "800000000000000000000000000",
        "stableRateSlope1": 0,
        "stableRateSlope2": 0,
        "variableRateSlope1": "40000000000000000000000000",
        "variableRateSlope2": "800000000000000000000000000"
      }
    }
  }
}
```