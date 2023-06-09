## Reserve changes

### Reserves added

#### rETH ([0xae78736Cd615f374D3085123A210448E74Fc6393](https://etherscan.io/address/0xae78736Cd615f374D3085123A210448E74Fc6393))

| description | value |
| --- | --- |
| decimals | 18 |
| isActive | true |
| isFrozen | false |
| supplyCap | 20,000 rETH |
| borrowCap | 2,400 rETH |
| debtCeiling | 0 $ |
| isSiloed | false |
| isFlashloanable | true |
| eModeCategory | 1 |
| oracle | [0x05225Cd708bCa9253789C1374e4337a019e99D56](https://etherscan.io/address/0x05225Cd708bCa9253789C1374e4337a019e99D56) |
| oracleName | rETH/ETH/USD |
| oracleLatestAnswer | 200,447,328,478 |
| usageAsCollateralEnabled | true |
| ltv | 68.5 % |
| liquidationThreshold | 79.5 % |
| liquidationBonus | 7 % |
| liquidationProtocolFee | 10 % |
| reserveFactor | 15 % |
| aToken | [0x9985dF20D7e9103ECBCeb16a84956434B6f06ae8](https://etherscan.io/address/0x9985dF20D7e9103ECBCeb16a84956434B6f06ae8) |
| aTokenImpl | [0x6175ddEc3B9b38c88157C10A01ed4A3fa8639cC6](https://etherscan.io/address/0x6175ddEc3B9b38c88157C10A01ed4A3fa8639cC6) |
| variableDebtToken | [0xBa2C8F2eA5B56690bFb8b709438F049e5Dd76B96](https://etherscan.io/address/0xBa2C8F2eA5B56690bFb8b709438F049e5Dd76B96) |
| variableDebtTokenImpl | [0x86C71796CcDB31c3997F8Ec5C2E3dB3e9e40b985](https://etherscan.io/address/0x86C71796CcDB31c3997F8Ec5C2E3dB3e9e40b985) |
| stableDebtToken | [0xa9a4037295Ea3a168DC3F65fE69FdA524d52b3e1](https://etherscan.io/address/0xa9a4037295Ea3a168DC3F65fE69FdA524d52b3e1) |
| stableDebtTokenImpl | [0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E](https://etherscan.io/address/0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E) |
| borrowingEnabled | true |
| stableBorrowRateEnabled | false |
| isBorrowableInIsolation | false |
| interestRateStrategy | [0x995c1A1Ee993031B9f3F268dD2B5E2AD7FE2CFdc](https://etherscan.io/address/0x995c1A1Ee993031B9f3F268dD2B5E2AD7FE2CFdc) |
| optimalUsageRatio | 45 % |
| maxExcessUsageRatio | 55 % |
| baseVariableBorrowRate | 0 % |
| variableRateSlope1 | 7 % |
| variableRateSlope2 | 300 % |
| baseStableBorrowRate | 7 % |
| stableRateSlope1 | 0 % |
| stableRateSlope2 | 0 % |
| optimalStableToTotalDebtRatio | 0 % |
| maxExcessStableToTotalDebtRatio | 100 % |
| interestRate | ![ir](/.assets/b092ae756c2e4a62477e7558d139088069f992d2.svg) |

### Reserves altered

#### DAI ([0x6B175474E89094C44Da98b954EedeAC495271d0F](https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F))

| description | value before | value after |
| --- | --- | --- |
| interestRateStrategy | [0x113dc45c524404F91DcbbAbB103506bABC8Df0FE](https://etherscan.io/address/0x113dc45c524404F91DcbbAbB103506bABC8Df0FE) | [0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d](https://etherscan.io/address/0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d) |
| baseRateConversion | 111.1111111111111111111111111 % | 100 % |
| interestRate | ![before](/.assets/f5a97b88e9c552c6b53cb889bf8aca2c2208024a.svg) | ![after](/.assets/bc11e5b92e27947ebc500895e90540b95b2b66a2.svg) |

## Raw diff

```json
{
  "reserves": {
    "0x6B175474E89094C44Da98b954EedeAC495271d0F": {
      "interestRateStrategy": {
        "from": "0x113dc45c524404F91DcbbAbB103506bABC8Df0FE",
        "to": "0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d"
      }
    },
    "0xae78736Cd615f374D3085123A210448E74Fc6393": {
      "from": null,
      "to": {
        "aToken": "0x9985dF20D7e9103ECBCeb16a84956434B6f06ae8",
        "aTokenImpl": "0x6175ddEc3B9b38c88157C10A01ed4A3fa8639cC6",
        "borrowCap": 2400,
        "borrowingEnabled": true,
        "debtCeiling": 0,
        "decimals": 18,
        "eModeCategory": 1,
        "interestRateStrategy": "0x995c1A1Ee993031B9f3F268dD2B5E2AD7FE2CFdc",
        "isActive": true,
        "isBorrowableInIsolation": false,
        "isFlashloanable": true,
        "isFrozen": false,
        "isSiloed": false,
        "liquidationBonus": 10700,
        "liquidationProtocolFee": 1000,
        "liquidationThreshold": 7950,
        "ltv": 6850,
        "oracle": "0x05225Cd708bCa9253789C1374e4337a019e99D56",
        "oracleLatestAnswer": 200447328478,
        "oracleName": "rETH/ETH/USD",
        "reserveFactor": 1500,
        "stableBorrowRateEnabled": false,
        "stableDebtToken": "0xa9a4037295Ea3a168DC3F65fE69FdA524d52b3e1",
        "stableDebtTokenImpl": "0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E",
        "supplyCap": 20000,
        "symbol": "rETH",
        "underlying": "0xae78736Cd615f374D3085123A210448E74Fc6393",
        "usageAsCollateralEnabled": true,
        "variableDebtToken": "0xBa2C8F2eA5B56690bFb8b709438F049e5Dd76B96",
        "variableDebtTokenImpl": "0x86C71796CcDB31c3997F8Ec5C2E3dB3e9e40b985"
      }
    }
  },
  "strategies": {
    "0x995c1A1Ee993031B9f3F268dD2B5E2AD7FE2CFdc": {
      "from": null,
      "to": {
        "baseStableBorrowRate": "70000000000000000000000000",
        "baseVariableBorrowRate": 0,
        "maxExcessStableToTotalDebtRatio": "1000000000000000000000000000",
        "maxExcessUsageRatio": "550000000000000000000000000",
        "optimalStableToTotalDebtRatio": 0,
        "optimalUsageRatio": "450000000000000000000000000",
        "stableRateSlope1": 0,
        "stableRateSlope2": 0,
        "variableRateSlope1": "70000000000000000000000000",
        "variableRateSlope2": "3000000000000000000000000000"
      }
    },
    "0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d": {
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