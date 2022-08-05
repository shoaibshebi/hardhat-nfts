//SPX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error AlreadyInitialized();
error NeedMoreETHSent();
error RangeOutOfBounds();

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage {
  enum Breed {
    PUG,
    SHIBA_INU,
    ST_BERNARD
  }
  //requestIdToSender maping
  mapping(uint256 => address) public s_requestIdToSender;

  //ChainlinkVrf vars
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  uint64 private immutable i_subscriptionId;
  bytes32 private immutable i_gasLane;
  uint32 private immutable i_callbackGasLimit;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;

  //Nft vars
  uint256 private i_mintFee;
  uint256 public s_tokenCounter; //by default 0
  uint256 public constant MAX_CHANCE_VALUE = 100;
  string[] public s_dogTokenUris;

  // Events
  event NftRequested(uint256 indexed requestId, address requester);
  event NftMinted(Breed breed, address minter);

  constructor(
    address vrfCoordinatorV2,
    uint64 subscriptionId,
    bytes32 gasLane, // keyHash
    uint256 mintFee,
    uint32 callbackGasLimit,
    string[3] memory dogTokenUris
  ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random IPFS NFT", "RIN") {
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_mintFee = mintFee;
    i_callbackGasLimit = callbackGasLimit;
    s_dogTokenUris = dogTokenUris;
  }

  function requestNft() public payable returns (uint256 requestId) {
    if (msg.value < i_mintFee) {
      revert NeedMoreETHSent();
    }
    //Generate a random ID using these all params
    requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane,
      i_subscriptionId,
      REQUEST_CONFIRMATIONS,
      i_callbackGasLimit,
      NUM_WORDS
    );

    //Assign nft owner against this requestId
    s_requestIdToSender[requestId] = msg.sender;
    emit NftRequested(requestId, msg.sender);
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
    internal
    override
  {
    address dogOwner = s_requestIdToSender[requestId];
    uint256 newItemId = s_tokenCounter;
    uint256 moddedBreed = randomWords[0] % MAX_CHANCE_VALUE;
    Breed dogBreed = getBreedFromModdedRng(moddedBreed);
    s_tokenCounter += s_tokenCounter;
    _safeMint(dogOwner, newItemId);
    //newItemId generated against each minted nft, is being assigned a token URI
    _setTokenURI(newItemId, s_dogTokenUris[uint256(dogBreed)]);
    emit NftMinted(dogBreed, dogOwner);
  }

  function withdraw() public {
    require(msg.sender == address(this));
    uint256 amount = address(this).balance;
    (bool success, ) = payable(msg.sender).call{ value: amount }("");
  }

  function getBreedFromModdedRng(uint256 moddedRng)
    public
    pure
    returns (Breed)
  {
    uint256 cumulativeSum = 0;
    uint256[3] memory chanceArray = getChanceArray();
    for (uint256 i = 0; i < chanceArray.length; i++) {
      if (moddedRng >= cumulativeSum && moddedRng < chanceArray[i]) {
        return Breed(i);
      }
      cumulativeSum = chanceArray[i];
    }
    revert RangeOutOfBounds();
  }

  function getChanceArray() public pure returns (uint256[3] memory) {
    return [10, 30, MAX_CHANCE_VALUE];
  }

  function getMintFee() public view returns (uint256) {
    return i_mintFee;
  }

  //whenever someone send index of their nft, we can get the token URI
  function getDogTokenUris(uint256 index) public view returns (string memory) {
    return s_dogTokenUris[index];
  }

  //how many tokens/nfts are minted yet
  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }
}
