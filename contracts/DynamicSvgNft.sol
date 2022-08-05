// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "base64-sol/base64.sol";

contract DynamicSvgNft is ERC721 {
  uint256 private s_tokenCounter; //by default 0
  string private s_lowImageURI;
  string private s_highImageURI;

  mapping(uint256 => int256) private s_tokenIdToHighValues;
  AggregatorV3Interface internal immutable i_priceFeed;
  event CreatedNFT(uint256 indexed tokenId, int256 highValue);

  constructor(
    address priceFeedAddress,
    string memory lowSvg,
    string memory highSvg
  ) ERC721("Dynamic SVG NFT", "DSN") {
    s_tokenCounter = 0;
    i_priceFeed = AggregatorV3Interface(priceFeedAddress);
    s_lowImageURI = svgToImageURI(lowSvg);
    s_highImageURI = svgToImageURI(highSvg);
  }

  //Whenever a new token is minted, we need to store the value (high value) of the token. it can be anything
  function mintNft(int256 highValue) public {
    s_tokenIdToHighValues[s_tokenCounter] = highValue;
    emit CreatedNFT(s_tokenCounter, highValue);
    _safeMint(msg.sender, s_tokenCounter);
    s_tokenCounter = s_tokenCounter + 1;
  }

  function svgToImageURI(string memory svg)
    public
    pure
    returns (string memory)
  {
    // example:
    // '<svg width="500" height="500" viewBox="0 0 285 350" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill="black" d="M150,0,L75,200,L225,200,Z"></path></svg>'
    // would return ""
    string memory baseURL = "data:image/svg+xml;base64,";
    string memory svgBase64Encoded = Base64.encode(
      bytes(string(abi.encodePacked(svg)))
    );
    return string(abi.encodePacked(baseURL, svgBase64Encoded));
  }

  function _baseURI() internal pure override returns (string memory) {
    return "data:application/json;base64,";
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    (, int256 price, , , ) = i_priceFeed.latestRoundData();
    string memory imageURI = s_lowImageURI;

    //if the price is higher than the high value, we use the high image, giving randomness to the imageUri
    if (price >= s_tokenIdToHighValues[tokenId]) {
      imageURI = s_highImageURI;
    }
    return
      string(
        abi.encodePacked(
          _baseURI(),
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                name(), // You can add whatever name here
                '", "description":"An NFT that changes based on the Chainlink Feed", ',
                '"attributes": [{"trait_type": "coolness", "value": 100}], "image":"',
                imageURI,
                '"}'
              )
            )
          )
        )
      );
  }
}
