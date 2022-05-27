# Infinite Auction House


 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *

This repo contains a proposed modification to the [auction mechanism](https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/NounsAuctionHouse.sol) used by [nounsDAO](https://github.com/nounsDAO) for their continuous supply mechanism. In the current model, a Noun is auctioned off every 24 hours and the ending of one auction initiates the auction of the next. I personally think this continuous drip of nft liquidity is a fantastic way to organicly bootstrap a community rather than a one time 10k pfp drop. The model works well for Nouns which is a high profile and ground breaking [hyperstructure](https://jacob.energy/hyperstructures.html), but may not work in all curcumstances. Other projects such as (lil nouns)[https://lilnouns.wtf/] are experimenting with high frequency auctions that allow for more liquidity and a more diverse community with a lower barrier to entry. 

The problem that becomes apparent now is that the current auction has a finite bid structure for an infinite supply structure. This fundimental mismatch becomes very apparent with higher frequency auctions as bids from previous rounds do not carry over into the next round. This leads to the following issues:

- **Inefficient**: Bidders have to pay a new gas fee every 15 mins to place a new bid if they do not win.
- **Fractured Liquidity**: Both financially and in attention. Bidders have to constantly pay attention to every new round of auctions which leads to...
- **Unpredictable Floor Bids**: Because the bids are swept every round, bidders are very likely to leave the auction area and not participate in the next round. This can lead to high variability in prices and can harm the DAO's ability to forecast future incomes. 

## Introducing the Infinite Auction House

In this new auction implementation, bids are carried over between auction rounds. This allows for a much more "Bid and Forget" mindset from auction participants. It also effectivly sets a floor bid for seccesive auctions, creating a much more predictable income stream for the DAO that is powering it. 

### Features
- **Bid and Forget**: Save gas and just bid once. If someone out bids you, you automatically become the top bid for the next round
- **Limit Bids**: Place a bid at exactly the max amount you are willing to pay. Successive auction rounds will work their way through higher bids until your bid becomes the top
- **Revoke Bid**: If you aren't currently winning the auction, you can revoke your bid a get a refund. 

### Usage

This model is envisioned for usage in expansions of the NounsDAO model which higher supply and more frequent auctions that may not be as popular as Nouns. It may also work well for projects on cheaper chains such as Polygon, Arbitrum, or Optimisim where the DAO can afford to automattically settle auctions so the bidders can truely "Bid and Forget". They will then be pleasantly surprised one day when their won NFT shows up in their wallet unannounced.   

