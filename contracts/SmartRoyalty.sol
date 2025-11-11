Events
    event ContentRegistered(uint256 indexed contentId, address indexed creator, string title);
    event RoyaltyDistributed(uint256 indexed contentId, uint256 amount, uint256 timestamp);
    event CreatorAdded(address indexed creator, string name);


    Percentage of revenue (0-100)
        uint256 totalEarnings;
        uint256 registrationTime;
        bool isActive;
    }
    
    Modifiers
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
    
    Update earnings
        content.totalEarnings += royaltyAmount;
        creators[creator].totalEarnings += royaltyAmount;
        totalRoyaltiesDistributed += royaltyAmount;
        
        Transfer platform fee to owner
        if (platformFee > 0) {
            payable(owner).transfer(platformFee);
        }
        
        emit RoyaltyDistributed(_contentId, royaltyAmount, block.timestamp);
    }
    
    Owner Functions
    
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
// 
End
// 
