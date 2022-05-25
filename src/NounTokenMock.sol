pragma solidity ^0.8.13;

import "nouns/interfaces/INounsToken.sol";

contract NounTokenMock {

    function mint() external returns (uint256) {
        return 1;
    }

    function burn(uint256 tokenId) external {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {}
}
