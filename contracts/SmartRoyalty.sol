// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SmartRoyalty
 * @dev Real-Time Royalty Distribution for Digital Creators
 * @author SmartRoyalty Team
 */
contract SmartRoyalty {

    // Events
    event ContentRegistered(uint256 indexed contentId, address indexed creator, string title);
    event RoyaltyDistributed(uint256 indexed contentId, uint256 amount, uint256 timestamp);
    event CreatorAdded(address indexed creator, string name);
    
    // Structures
    struct Creator {
        string name;
        uint256 totalEarnings;
        bool isRegistered;
        uint256 contentCount;
    }
    
    struct Content {
        uint256 id;
        string title;
        string description;
        address creator;
        uint256 royaltyPercentage; // Percentage of revenue (0-100)
        uint256 totalEarnings;
        uint256 registrationTime;
        bool isActive;
    }
    
    // State Variables
    mapping(address => Creator) public creators;
    mapping(uint256 => Content) public contents;
    mapping(address => uint256[]) public creatorContents;
    
    uint256 public nextContentId = 1;
    uint256 public totalContentCount = 0;
    uint256 public totalRoyaltiesDistributed = 0;
    
    address public owner;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredCreator() {
        require(creators[msg.sender].isRegistered, "Creator not registered");
        _;
    }
    
    modifier validContentId(uint256 _contentId) {
        require(_contentId > 0 && _contentId < nextContentId, "Invalid content ID");
        require(contents[_contentId].isActive, "Content is not active");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Register a new creator
     * @param _name Creator's name
     */
    function registerCreator(string memory _name) external {
        require(!creators[msg.sender].isRegistered, "Creator already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        creators[msg.sender] = Creator({
            name: _name,
            totalEarnings: 0,
            isRegistered: true,
            contentCount: 0
        });
        
        emit CreatorAdded(msg.sender, _name);
    }
    
    /**
     * @dev Register new digital content for royalty tracking
     * @param _title Content title
     * @param _description Content description
     * @param _royaltyPercentage Royalty percentage (0-100)
     */
    function registerContent(
        string memory _title,
        string memory _description,
        uint256 _royaltyPercentage
    ) external onlyRegisteredCreator {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_royaltyPercentage <= 100, "Royalty percentage cannot exceed 100%");
        
        uint256 contentId = nextContentId;
        
        contents[contentId] = Content({
            id: contentId,
            title: _title,
            description: _description,
            creator: msg.sender,
            royaltyPercentage: _royaltyPercentage,
            totalEarnings: 0,
            registrationTime: block.timestamp,
            isActive: true
        });
        
        creatorContents[msg.sender].push(contentId);
        creators[msg.sender].contentCount++;
        totalContentCount++;
        nextContentId++;
        
        emit ContentRegistered(contentId, msg.sender, _title);
    }
    
    /**
     * @dev Distribute royalties to content creator
     * @param _contentId ID of the content
     */
    function distributeRoyalty(uint256 _contentId) external payable validContentId(_contentId) {
        require(msg.value > 0, "Amount must be greater than 0");
        
        Content storage content = contents[_contentId];
        address creator = content.creator;
        
        uint256 royaltyAmount = (msg.value * content.royaltyPercentage) / 100;
        uint256 platformFee = msg.value - royaltyAmount;
        
        // Update earnings
        content.totalEarnings += royaltyAmount;
        creators[creator].totalEarnings += royaltyAmount;
        totalRoyaltiesDistributed += royaltyAmount;
        
        // Transfer royalty to creator
        if (royaltyAmount > 0) {
            payable(creator).transfer(royaltyAmount);
        }
        
        // Transfer platform fee to owner
        if (platformFee > 0) {
            payable(owner).transfer(platformFee);
        }
        
        emit RoyaltyDistributed(_contentId, royaltyAmount, block.timestamp);
    }
    
    // View Functions
    
    /**
     * @dev Get creator information
     * @param _creator Creator's address
     */
    function getCreator(address _creator) external view returns (
        string memory name,
        uint256 totalEarnings,
        bool isRegistered,
        uint256 contentCount
    ) {
        Creator memory creator = creators[_creator];
        return (creator.name, creator.totalEarnings, creator.isRegistered, creator.contentCount);
    }
    
    /**
     * @dev Get content information
     * @param _contentId Content ID
     */
    function getContent(uint256 _contentId) external view returns (
        uint256 id,
        string memory title,
        string memory description,
        address creator,
        uint256 royaltyPercentage,
        uint256 totalEarnings,
        uint256 registrationTime,
        bool isActive
    ) {
        Content memory content = contents[_contentId];
        return (
            content.id,
            content.title,
            content.description,
            content.creator,
            content.royaltyPercentage,
            content.totalEarnings,
            content.registrationTime,
            content.isActive
        );
    }
    
    /**
     * @dev Get all content IDs for a creator
     * @param _creator Creator's address
     */
    function getCreatorContents(address _creator) external view returns (uint256[] memory) {
        return creatorContents[_creator];
    }
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats() external view returns (
        uint256 totalContents,
        uint256 totalRoyalties,
        uint256 nextId
    ) {
        return (totalContentCount, totalRoyaltiesDistributed, nextContentId);
    }
    
    // Owner Functions
    
    /**
     * @dev Emergency withdraw function (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Transfer ownership (only owner)
     * @param _newOwner New owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
