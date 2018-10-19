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
invoke `GringottsBank.claimDeposit`

### 3. how to withdraw RING before maturity
invoke
```js
// _data = uint2Bytes(depositID)
kryptonite_.transfer(address_of_GringottsBank, amount_of_KTON_as_penalty, _data)
```

### 4.Test addresses on Kovan network.
```
KTON: 0x8db914ef206c7f6c36e5223fce17900b587f46d2
bankProxy: 0x33dcd37b0b7315105859f9aa4b603339ad8825fc
bankLogic: 0x834c672f4fe27df295f624e91b64e6f4e01d83bb
bankAuthority: 0x34ebd9edfdaed8dc578b7390d62abf43044fdfb2
```

### 5. Versions of Bank Logic Contracts
```python
V0: 0x76cd2e158e8cb48523da1ffb83f64331544ae9d4
V1: 0x834c672f4fe27df295f624e91b64e6f4e01d83bb
```



