## Reserve changes

### Reserve altered

#### DAI ([0x6B175474E89094C44Da98b954EedeAC495271d0F](https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F))

| description | value before | value after |
| --- | --- | --- |
| ltv | 74 % | 1 % |
| liquidationThreshold | 76 % | 1 % |
| interestRateStrategy | [0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d](https://etherscan.io/address/0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d) | [0x191E97623B1733369290ee5d018d0B068bc0400D](https://etherscan.io/address/0x191E97623B1733369290ee5d018d0B068bc0400D) |
| interestRate | ![before](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) | ![after](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) |

#### WETH ([0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2](https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2))

| description | value before | value after |
| --- | --- | --- |
| reserveFactor | 15 % | 5 % |
| interestRateStrategy | [0x764b4AB9bCA18eB633d92368F725765Ebb8f047C](https://etherscan.io/address/0x764b4AB9bCA18eB633d92368F725765Ebb8f047C) | [0x36e9A9e26713fb45EB957609Ebb0fa37d9114d28](https://etherscan.io/address/0x36e9A9e26713fb45EB957609Ebb0fa37d9114d28) |
| variableRateSlope1 | 3.8 % | 3 % |
| baseStableBorrowRate | 3.8 % | 3 % |
| interestRate | ![before](/.assets/6747e3b5adc7a63d169daf26756fbbc8cc8e1802.svg) | ![after](/.assets/8b2de7113791e0c12220a037d370b57b6da59d02.svg) |

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
        "to": 100
      },
      "ltv": {
        "from": 7400,
        "to": 100
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
        "baseStableBorrowRate": "30000000000000000000000000",
        "baseVariableBorrowRate": "10000000000000000000000000",
        "maxExcessStableToTotalDebtRatio": "1000000000000000000000000000",
        "maxExcessUsageRatio": "200000000000000000000000000",
        "optimalStableToTotalDebtRatio": 0,
        "optimalUsageRatio": "800000000000000000000000000",
        "stableRateSlope1": 0,
        "stableRateSlope2": 0,
        "variableRateSlope1": "30000000000000000000000000",
        "variableRateSlope2": "800000000000000000000000000"
      }
    }
  }
}
```