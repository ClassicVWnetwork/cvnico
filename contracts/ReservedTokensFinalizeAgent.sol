pragma solidity ^0.4.6;

import "./SafeMathLibExt.sol";
import "./CrowdsaleExt.sol";
import "./CrowdsaleTokenExt.sol";

/**
 * The default behavior for the crowdsale end.
 *
 * Unlock tokens.
 */
contract ReservedTokensFinalizeAgent is FinalizeAgent {
  using SafeMathLibExt for uint;
  CrowdsaleTokenExt public token;
  CrowdsaleExt public crowdsale;

  bool public reservedTokensAreDistributed = false;
  uint public distributedReservedTokensDestinationsLen = 0;

  function ReservedTokensFinalizeAgent(CrowdsaleTokenExt _token, CrowdsaleExt _crowdsale) {
    token = _token;
    crowdsale = _crowdsale;
  }

  /** Check that we can release the token */
  function isSane() public constant returns (bool) {
    return (token.releaseAgent() == address(this));
  }

  //distributes reserved tokens. Should be called before finalization
  function distributeReservedTokens(uint reservedTokensDistributionBatch) public {
    if(msg.sender != address(crowdsale)) {
      throw;
    }

    assert(reservedTokensDistributionBatch > 0);
    assert(!reservedTokensAreDistributed);
    assert(distributedReservedTokensDestinationsLen < token.reservedTokensDestinationsLen());

    // How many % of tokens the founders and others get
    uint tokensSold = crowdsale.tokensSold();

    uint startLooping = distributedReservedTokensDestinationsLen;
    uint batch = token.reservedTokensDestinationsLen().minus(distributedReservedTokensDestinationsLen);
    if (batch >= reservedTokensDistributionBatch) {
      batch = reservedTokensDistributionBatch;
    }
    uint endLooping = startLooping + batch;

    // move reserved tokens
    for (uint j = startLooping; j < endLooping; j++) {
      address reservedAddr = token.reservedTokensDestinations(j);
      if (!token.areTokensDistributedForAddress(reservedAddr)) {
        uint allocatedBonusInPercentage;
        uint allocatedBonusInTokens = token.getReservedTokens(reservedAddr);
        uint percentsOfTokensUnit = token.getReservedPercentageUnit(reservedAddr);
        uint percentsOfTokensDecimals = token.getReservedPercentageDecimals(reservedAddr);

        if (percentsOfTokensUnit > 0) {
          allocatedBonusInPercentage = tokensSold * percentsOfTokensUnit / 10**percentsOfTokensDecimals / 100;
          token.mint(reservedAddr, allocatedBonusInPercentage);
        }

        if (allocatedBonusInTokens > 0) {
          token.mint(reservedAddr, allocatedBonusInTokens);
        }

        token.finalizeReservedAddress(reservedAddr);
        distributedReservedTokensDestinationsLen++;
      }
    }

    if (distributedReservedTokensDestinationsLen == token.reservedTokensDestinationsLen()) {
      reservedTokensAreDistributed = true;
    }
  }

  /** Called once by crowdsale finalize() if the sale was success. */
  function finalizeCrowdsale() public {
    if(msg.sender != address(crowdsale)) {
      throw;
    }

    if (token.reservedTokensDestinationsLen() > 0) {
      assert(reservedTokensAreDistributed);
    }

    token.releaseTokenTransfer();
  }

}