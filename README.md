# Entertainmint contracts

Entertainmint is a crowdfunding platform for independent TV, film, and video content creators. Fans and brands may purchase NFT "tickets" on the Entertainmint platform to support creators and their projects. The V1 contracts implement a Kickstarter-like crowdfund model, where creators set a funding goal amount and funds are distributed once it is met, or refunded if it is not. Although our initial launch focuses on crowdfunding, we have designed the system to be modular and extensible to other use cases in the future, including NFT editions, merchandise drops, one time "viewer" tokens and more.

Please see the "Contracts" section below for more details on each contract.

## Setup

Install [foundry](https://github.com/foundry-rs/foundry):

```bash
$ curl -L https://foundry.paradigm.xyz | bash
```

Then in a new terminal or after reloading your `PATH`, run:

```bash
$ foundryup
```

Install dependencies and compile contracts with:

```bash
$ forge build
```

## Running tests

Unit tests are in the `tests/` directory, with one file per contract. We use separate contracts within each test file to isolate tests in different contexts.

In addition to unit tests, `tests/fork/EmintV1.t.sol` tests the raise workflow end to end, including contract deployment, in a forked mainnet environment.

To run tests, first ensure you've created a `.env` file and added RPC URL environment variables:

```bash
$ cp .env.example .env
```

Then run:

```bash
$ forge test
```

## Deployment

We use Forge scripts for deployment. To deploy the full system, run:

```bash
$ forge script script/deployments/DeployEmintV1.sol
```

## Contracts

![Contracts](doc/contracts.png)

### Controller

The `Controller` is the system admin module, a central contract with authority to pause and unpause contracts, update contract dependencies, manage allowlists, and execute arbitrary calls. The owner of this contract has full access to these privileged admin functions. Additionally, this contract maintains a mapping of authorized "pauser" addresses, with limited access only to pause and unpause contracts.

### CreatorAuth

`CreatorAuth` is an allowlist of approved creator addresses. Our V1 system is not fully permissionless and Entertainmint admins will initially approve authorized creators to interact with the system. If a creator's address is not on the `CreatorAuth` allowlist, they should not be allowed to create projects or raises. `CreatorAuth` inherits an abstract `AllowList` contract, which we use in a few places throughout the codebase.

### Creators

`Creators` is the public facing interface contract for creators to interact with the protocol, and the single external point of entry for all creators. Creators use this contract to register new projects, transfer ownership of existing projects, create and configure raises, and manage token metadata. Except for module dependencies, this is a stateless contract that orchestrates interactions with other modules. All creators must be authorized by `CreatorAuth` to interact with this contract.

### Metadata

`Metadata` is responsible for resolving metadata URIs on behalf of deployed `Emint1155` token contracts. `Emint1155` tokens delegate `uri` and `contractURI` calls to the `Metadata` module. Token owners have three options for token metadata:

- By default, tokens will use a default metadata URI hosted at `https://entertainmint.com/api/metadata/<tokenId>.json`.
- Token owners may specify a custom metadata URI by token ID using `setCustomURI`.
- Token owners may specify a custom metadata resolver contract using `setCustomURI`. This contract must conform to the `IMetadataResolver` interface. If a custom resolver contract is present, it takes precedent over an existing custom URI.

At least for V1, we expect most users to use the default hosted URI.

### Minter

`Minter` is the only module in the system authorized to directly mint tokens. It maintains an allowlist of external contracts with permission to mint `Emint1155` tokens.

### Projects

`Projects` is a registry of projects and their owners, tracking project IDs and owner accounts. Projects use simple sequential IDs. Owners can transfer projects to a new account using a two step transfer/accept system. This is an "internal" contract: creators are not meant to directly interact with the `Projects` contract, but rather to use `Creators` as their external interface to the system.

### Raises

`Raises` is the most complex contract in V1, implementing crowdfund creation, management, and settlement. External users will interact with this contract to mint tokens in support of successful projects, and redeem tokens from failed raises. As such, this is the most "public-facing" contract with the greatest exposure to potentially malicious users.

A `Raise` represents a single fundraising round. One project may create many raises over time, in order to fund multiple distinct initiatives, like individual seasons of a specific series.

**Setup**

When creating a `Raise`, the creator specifies a `goal` amount to raise, and a `max`, which serves as a cap on the total amount to raise. Additionally, they must provide timestamps for the presale and public sale phases of the raise, and a "currency" (either an ERC20 token or native ETH). We intend to support only native ETH and USDC at launch.

Additionally, a raise includes multiple `Tier`s, representing the configuration of the tokens associated with the raise. Off-chain, tiers may have different perks and benefits associated with their tokens. We support two distinct types of tiers: "fan" tokens are intended for purchase by project patrons, while "brand" tokens are intended for purchase by brands. Fan tokens have a lower protocol fee and royalties than brand tokens. Each tier has a fixed supply, price per token, and mint limit by address. Each tier may optionally include an allowlist Merkle root describing addresses allowed to mint tokens during the presale phase.

**States**

A raise may be in one of three `state`s, depending on whether it has ended and has or has not met its funding goal:

- An `Active` raise has not yet ended.
- A `Funded` raise has ended and met its goal.
- A `Cancelled` raise has either did not meet its goal, or was cancelled by the owner.

**Phases**

In addition to its state, a raise has a `phase` based on the current timestamp and the raise's configured schedule. A raise's `phase` is calculated using the `Phases` library.

- A `Scheduled` raise is not open for minting. If a raise is `Scheduled` the current time is either before the `Presale` phase or between `Presale` and `PublicSale`.
- The `Presale` phase is between the raise's `presaleStart` and `presaleEnd` timestamps. If the current time is in this interval, the raise is in `Presale` and allowlisted users may mint tokens.
- The `PublicSale` phase is between the raise's `publicSaleStart` and `publicSaleEnd` timestamps. If the current time is in this interval, anyone may mint a token subject to available supply.
- If the current time is after the `publicSaleEnd` timestamp, the raise has `Ended` and all mints are closed.

**Tokens**

Each raise deploys two `Emint1155` token contracts: one for fan tokens and one for brand tokens. This design is intended to give creators ownership over "their own" token contract on OpenSea and other marketplaces, and ensures that they appear as separate collections on marketplace frontends. Additionally, since major marketplaces like OpenSea rely on contract-level metadata for royalty information, this allows fan and brand tokens to specify different royalty configurations. Contracts are deployed as minimal clones—see the `TokenDeployer` docs for more details.

**Updates**

Creators may update a raise as long as it is has not yet started, i.e. it is `Active` and `Scheduled`.

**Minting**

During a raise's `Presale` and `PublicSale` phases, users may mint tokens in support of a project. In the presale phase, minters must provide a Merkle proof of inclusion on a given tier's allow list. Users may mint multiple tokens, subject to supply and the per-address mint limit. (We acknowledge that per-address mint limits are pretty easy to circumvent by sophisticated users). Minting transfers payment in ETH or ERC20 into the contract in exchange for an `Emint1155` token.

**Settlement**

Once a raise has `Ended`, any external user may call `settle` to settle the raise and transition its state to either `Funded` or `Cancelled`. If the raise met its goal, it transitions to `Funded` and the creator may withdraw the collected funds. If the raise failed to meet its goal, it transitions to `Cancelled`, and users may redeem their tokens for a refund.

**Redemption**

If a raise is `Cancelled` users may optionally exchange their `Emint1155` tier tokens for a refund. (This is not required: if they choose to keep their tokens rather than requesting a refund, they may do so.) Redemption burns their token and refunds the amount collected in exchange for the token.

**Withdrawal**

If a raise is `Funded`, the creator may withdraw raise funds to a specified address. This transfers the full balance of the raise to the given `receiver` address.

Additionally, the `Controller` may withdraw accrued protocol fees to an arbitrary address of its choice.

**Closure**

Once a raise has met its funding goal, its owner may optionally choose to close it early. Calling `close` immediately sets a raise's state to `Funded` if it has met its goal.

**Cancellation**

At any time, the raise's owner may cancel the raise. This immediately sets the raise state to `Cancelled` and allows users to `redeem` their tokens for a refund.

### Royalties

`Royalties` is a royalties registry for Emint1155 tokens. Tokens delegate ERC-2981 `royaltyInfo` requests to the `Royalties` contract, which calculates different royalty amounts for different token types.

### TokenAuth

`TokenAuth` is an allowlist of authorized ERC20 tokens. For V1, we intend to support only USDC. Any ERC20 tokens used as currency for a raise must be allowlisted in this contract. We do not intend to support ERC777 tokens, fee-on-transfer or rebasing tokens, or other weird ERC20s for payment.

### TokenDeployer

`TokenDeployer` clones and registers new `Emint1155` token contract instances. It's the only module in the system authorized to deploy tokens.

### Tokens

`Tokens` is responsible for deploying new `Emint1155` token contracts, and maintaining an internal registry mapping token IDs to contract addresses. Many token IDs may map to a single contract address. Token contract instances are deployed as EIP-1167 clones.

### Emint1155

`Emint1155` is a burnable ERC-1155 token contract. Since it is the implementation contract for the clones created by `Tokens`, it uses upgradeable dependencies, even though it is not itself an upgradeable contract. It's a pretty standard 1155 contract which delegates royalty related queries to the `Royalties` module and metadata related queries to the `Metadata` module. Additionally, this contract implements the ERC-2981 royalty interface, and OpenSea's new operator filter requirements.

### Token ID Codecs

We use globally unique synthetic token IDs across all Emint1155 contracts. Each token ID encodes information about its token type and encoding version, as well as a type-specfic data payload that includes additional information. For example, raise tokens encode their project ID, raise ID, tier ID, and tier type. (In an earlier iteration of the design, tokens used a single ERC1155 contract. Although we now deploy separate contracts per raise, we have maintained this synthetic ID schema across token contract instances since it's useful to decode token information from the ID offchain).

Only raise tokens are implemented in the V1 contracts, but we anticipate extending this schema to other types of tokens, like editions and merchandise tokens in the future.

Token schema:

```
  |------------ Token data is encoded in 32 bytes ---------------|
0x0000000000000000000000000000000000000000000000000000000000000000
  1 byte token type                                             tt
  1 byte encoding version                                     vv
  |------------------ 30 byte data region -------------------|
```

Raise token data schema:

```
  |------- Raise token data is encoded in 30 bytes ----------|
0x000000000000000000000000000000000000000000000000000000000000
  4 byte project ID                                   pppppppp
  4 byte raise ID                             rrrrrrrr
  4 byte tier ID                      tttttttt
  1 byte tier type                  TT
  |--------------------------------|  17 empty bytes reserved
```
