## Reserve changes

### Reserve altered

#### DAI ([0x6B175474E89094C44Da98b954EedeAC495271d0F](https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F))

| description | value before | value after |
| --- | --- | --- |
| interestRateStrategy | [0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d](https://etherscan.io/address/0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d) | [0x191E97623B1733369290ee5d018d0B068bc0400D](https://etherscan.io/address/0x191E97623B1733369290ee5d018d0B068bc0400D) |
| interestRate | ![before](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) | ![after](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) |

#### sDAI ([0x83F20F44975D03b1b09e64809B757c47f942BEeA](https://etherscan.io/address/0x83F20F44975D03b1b09e64809B757c47f942BEeA))

| description | value before | value after |
| --- | --- | --- |
| oracleLatestAnswer | 102,556,385 | 102,557,375 |


## Raw diff

```json
{
  "reserves": {
    "0x6B175474E89094C44Da98b954EedeAC495271d0F": {
      "interestRateStrategy": {
        "from": "0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d",
        "to": "0x191E97623B1733369290ee5d018d0B068bc0400D"
      }
    },
    "0x83F20F44975D03b1b09e64809B757c47f942BEeA": {
      "oracleLatestAnswer": {
        "from": 102556385,
        "to": 102557375
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
    }
  }
}
```