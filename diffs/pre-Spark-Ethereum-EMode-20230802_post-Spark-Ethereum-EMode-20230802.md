## Reserve changes

### Reserve altered

#### wstETH ([0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0](https://etherscan.io/address/0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0))

| description | value before | value after |
| --- | --- | --- |
| eModeCategory | 1 | 3 |


#### sDAI ([0x83F20F44975D03b1b09e64809B757c47f942BEeA](https://etherscan.io/address/0x83F20F44975D03b1b09e64809B757c47f942BEeA))

| description | value before | value after |
| --- | --- | --- |
| eModeCategory | 0 | 2 |


#### WETH ([0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2](https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2))

| description | value before | value after |
| --- | --- | --- |
| eModeCategory | 1 | 2 |


## Raw diff

```json
{
  "eModes": {
    "2": {
      "from": null,
      "to": {
        "eModeCategory": 2,
        "label": "sDAI allowed - WETH",
        "liquidationBonus": 10500,
        "liquidationThreshold": 8251,
        "ltv": 8001,
        "priceSource": "0x0000000000000000000000000000000000000000"
      }
    },
    "3": {
      "from": null,
      "to": {
        "eModeCategory": 3,
        "label": "sDAI allowed - wstETH",
        "liquidationBonus": 10700,
        "liquidationThreshold": 7951,
        "ltv": 6851,
        "priceSource": "0x0000000000000000000000000000000000000000"
      }
    }
  },
  "reserves": {
    "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0": {
      "eModeCategory": {
        "from": 1,
        "to": 3
      }
    },
    "0x83F20F44975D03b1b09e64809B757c47f942BEeA": {
      "eModeCategory": {
        "from": 0,
        "to": 2
      }
    },
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2": {
      "eModeCategory": {
        "from": 1,
        "to": 2
      }
    }
  }
}
```