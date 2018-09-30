# bank

### abstract
GringottsBank is a virtual bank in evolution land. It is a magic place it can give you kryptonite(KTON, an ERC20 token) as interest if you deposit RING into it.

kryptonite can also used to buy land assets in evolution land. Specifically, players can only buy the reserved land and other special lands with kryptonite.

### deployment
deploy contract `GringottsBank`.
constructor's paramaters:
1. address _ring: address of token contract of RING
2. address _kton: address of token contract of KTON


### Usage
#### 1. how to deposit RING
invoke 
```js
// _data = uint2Bytes(how_many_months_you_wants_to_lock_your_ring_for)
ring_.transfer(address_of_GringottsBank, amount_of_ring, _data)
```

#### 2. How to withdraw RING after maturity
invoke `GringottsBank.claimBack`

### 3. how to withdraw RING before maturity
invoke
```js
// _data = uint2Bytes(depositID)
kryptonite_.transfer(address_of_GringottsBank, amount_of_KTON_as_penalty, _data)
```

### 4.Test addresses on Kovan network.
```
KTON: 0x32965b675355e07c7172D543D00bfa85f71f1D37
BANK: 0xa32adc22731bb80e572110c2fdb1f41dd2752e37
```



