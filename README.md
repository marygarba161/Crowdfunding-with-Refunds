# 🎯 Crowdfunding with Refunds Smart Contract

A decentralized crowdfunding platform built on Stacks blockchain that automatically handles refunds when campaigns don't reach their funding goals! 💰

## ✨ Features

- 🚀 **Create Campaigns**: Launch crowdfunding campaigns with custom goals and deadlines
- 💸 **Contribute Funds**: Support campaigns with STX tokens
- 🎉 **Claim Success**: Creators can claim funds when goals are reached
- 🔄 **Automatic Refunds**: Contributors get refunds if campaigns fail to reach goals
- ⏰ **Time-based Logic**: Campaigns have deadlines for conditional execution
- 📊 **Status Tracking**: Real-time campaign progress and status monitoring

## 🛠️ Core Functions

### 📝 Campaign Management
- `create-campaign` - Create a new crowdfunding campaign
- `end-campaign` - Manually end a campaign (creator only)
- `get-campaign` - View campaign details

### 💰 Funding Operations
- `contribute` - Contribute STX to a campaign
- `claim-funds` - Claim funds when goal is reached (creator only)
- `request-refund` - Get refund when goal isn't reached

### 📈 Status Queries
- `get-campaign-status` - Check if goal reached, deadline passed, etc.
- `can-claim-funds` - Check if funds can be claimed
- `can-request-refund` - Check if refund is available
- `get-contribution` - View contribution details

## 🚀 Usage Examples

### Creating a Campaign
```clarity
(contract-call? .crowdfunding-with-refunds create-campaign 
  "My Awesome Project" 
  "Building the future of decentralized apps" 
  u1000000 
  u1000)
```

### Contributing to Campaign
```clarity
(contract-call? .crowdfunding-with-refunds contribute u1 u100000)
```

### Claiming Funds (Success)
```clarity
(contract-call? .crowdfunding-with-refunds claim-funds u1)
```

### Requesting Refund (Failure)
```clarity
(contract-call? .crowdfunding-with-refunds request-refund u1)
```

## 🎯 Campaign Lifecycle

1. **📅 Creation**: Set goal amount and deadline
2. **💵 Funding Period**: Contributors send STX before deadline
3. **⚖️ Evaluation**: After deadline, check if goal was reached
4. **🎊 Success Path**: Creator claims funds if goal reached
5. **💔 Failure Path**: Contributors request refunds if goal not reached

## 🔒 Security Features

- ✅ Only campaign creators can claim funds or end campaigns
- ✅ Contributions only accepted before deadline
- ✅ Funds only claimable after deadline and when goal reached
- ✅ Refunds only available when goal not reached
- ✅ Prevents double-claiming of funds or refunds

## 📊 Error Codes

- `u100` - Owner only operation
- `u101` - Campaign not found
- `u102` - Already exists
- `u103` - Invalid amount
- `u104` - Campaign ended
- `u105` - Campaign still active
- `u106` - Goal not reached
- `u107` - Goal already reached
- `u108` - No contribution found
- `u109` - Already claimed

## 🧪 Testing

Deploy with Clarinet and test the conditional logic:

```bash
clarinet console
```

Test successful campaign flow and failed campaign refund scenarios to see the conditional logic in action! 🎮

## 🎓 Learning Outcomes

This contract teaches:
- ⚡ **Conditional Logic**: Different execution paths based on goal achievement
- ⏰ **Time-based Contracts**: Using block height for deadlines  
- 💰 **Token Transfers**: Handling STX deposits and withdrawals
- 🗺️ **State Management**: Complex data relationships with maps
- 🛡️ **Access Control**: Role-based permissions and validations

Perfect for learning how smart contracts can automatically execute different outcomes based on conditions! 🚀
```

**Git Commit Message:**
```
feat: implement crowdfunding contract with conditional refund logic
```

**GitHub Pull Request Title:**
```
🎯 Add Crowdfunding with Refunds Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## 🚀 What's Added

Implemented a complete crowdfunding smart contract with automatic refund functionality that demonstrates conditional logic execution.

### ✨ Key Features
- Campaign creation with goals and deadlines
- STX contribution handling with automatic escrow
- Conditional fund claiming when goals are reached
- Automatic refund system when campaigns fail
- Time-based deadline enforcement using block height
- Comprehensive status tracking and validation

### 🎓 Educational Value
Perfect example of conditional logic in smart contracts - funds flow to creators on success, back to contributors on failure. Teaches time-based contract execution, state management, and token handling patterns.

### 🧪 Ready for Testing
Includes complete function set for creating, funding, and resolving campaigns with proper error handling and access controls.# Crowdfunding with Refunds

