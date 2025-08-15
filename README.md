# Restaurant Feedback DAO 🍴

A decentralized autonomous organization for restaurant feedback where regular diners hold NFT access passes and vote on menu changes, service improvements, and more. Top contributors get exclusive perks! 

## Features ✨

### 🎫 NFT Access System
- **Diner Pass NFTs**: Exclusive access tokens for restaurant patrons
- **Voting Power**: Based on reputation score and participation history
- **Transferable**: Pass NFTs can be transferred between users

### 🗳️ Governance System
- **Proposal Creation**: Submit menu changes, service improvements, and restaurant policies
- **Democratic Voting**: Vote on proposals with weighted voting power
- **Execution**: Automatically execute successful proposals
- **Categories**: Menu items, service quality, ambiance, events, and policies

### 🏆 Reputation & Rewards
- **Reputation Scoring**: Earn points through voting and successful proposals
- **Voting Power**: Increases with reputation (base 1 + reputation/10)
- **Exclusive Perks**: VIP reservations, discounts, and special events
- **Activity Tracking**: Monitor member engagement and contributions

## Smart Contract Functions 📋

### Public Functions

#### NFT Management
- `mint-diner-pass(recipient)` - Mint new diner pass (owner only)
- `transfer(token-id, sender, recipient)` - Transfer NFT ownership
- `batch-mint-passes(recipients)` - Mint multiple passes at once

#### Governance
- `create-proposal(title, description, type, voting-period)` - Submit new proposal
- `vote(proposal-id, support)` - Cast vote on proposal (true/false)
- `execute-proposal(proposal-id)` - Execute successful proposal after voting ends

#### Perks & Rewards
- `claim-perk(perk-type)` - Claim available perks based on reputation
- `update-restaurant-name(new-name)` - Update restaurant name (owner only)

### Read-Only Functions

#### NFT Info
- `get-owner(token-id)` - Get NFT owner
- `get-last-token-id()` - Get latest minted token ID
- `get-token-uri(token-id)` - Get token metadata URI

#### Governance Info
- `get-proposal(proposal-id)` - Get proposal details
- `get-proposal-results(proposal-id)` - Get voting results and status
- `get-vote(proposal-id, voter)` - Check user's vote on proposal

#### Member Info
- `get-member-stats(member)` - Get member voting history and reputation
- `get-voting-power(member)` - Calculate member's current voting power
- `get-member-perks(member)` - Get member's perk eligibility status
- `is-eligible-for-perk(member, perk-type)` - Check perk eligibility

## Usage Instructions 🚀

### Getting Started

1. **Get a Diner Pass**: Contact the restaurant owner to receive your NFT access pass
2. **Participate**: Start voting on proposals to build your reputation
3. **Create Proposals**: Submit ideas for menu changes or service improvements
4. **Earn Rewards**: Accumulate reputation points to unlock exclusive perks

### Voting Process

1. **Browse Proposals**: Check active proposals using off-chain indexing
2. **Cast Your Vote**: Use `vote()` function with proposal ID and true/false
3. **Track Results**: Monitor proposal progress and outcomes
4. **Claim Rewards**: Successful proposal creators earn bonus reputation

### Perk System

| Reputation Level | Voting Power | Available Perks |
|-----------------|--------------|----------------|
| 0-49 points     | 1x           | Basic access   |
| 50-99 points    | 6x           | Priority reservations |
| 100+ points     | 11x+         | VIP events, discounts |

### Proposal Types

- 🥘 **Menu Changes**: New dishes, seasonal items, dietary options
- 🎯 **Service Improvements**: Staff training, ordering systems, wait times
- 🎨 **Ambiance Updates**: Decor, music, lighting, seating arrangements
- 🎉 **Events**: Special dinners, wine tastings, chef collaborations
- 📋 **Policies**: Hours, reservations, loyalty programs

## Error Codes 🚨

- `u100` - Owner only function
- `u101` - Not token owner  
- `u102` - Proposal not found
- `u103` - Already voted on proposal
- `u104` - Voting period ended
- `u105` - Invalid proposal data
- `u106` - Insufficient balance
- `u107` - Must own diner pass NFT
- `u108` - Proposal already executed
- `u109` - Proposal failed (more no votes)
- `u110` - Not eligible for perk

## Development Setup 🛠️

```bash
# Install Clarinet
npm install -g @hirosystems/clarinet-cli

# Check contract syntax
clarinet check

# Run tests
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

## Contributing 🤝

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `clarinet check` to verify
5. Submit a pull request

## Restaurant Integration 🏪

This DAO system can be customized for any restaurant by:
- Updating the restaurant name via `update-restaurant-name()`
- Customizing perk types and eligibility requirements
- Implementing off-chain proposal management
- Integrating with existing POS and reservation systems

---

*Built with ❤️ on Stacks blockchain*
