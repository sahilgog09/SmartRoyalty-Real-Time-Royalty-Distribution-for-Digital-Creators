// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    uint256 public constant BASIS_POINTS = 10_000;

    struct RoyaltyInfo {
        address recipient;
        uint256 share; // in basis points
    }

    mapping(uint256 => RoyaltyInfo[]) private royalties;

    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesPaid(uint256 indexed contentId, uint256 amount);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validInput(address[] calldata recipients, uint256[] calldata shares) {
        uint256 len = recipients.length;
        require(len > 0 && len == shares.length, "Invalid input");
        _;
    }

    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external validInput(recipients, shares) {
        delete royalties[contentId];
        uint256 totalShare;
        RoyaltyInfo[] storage dist = royalties[contentId];

        for (uint256 i; i < recipients.length; ++i) {
            address recipient = recipients[i];
            uint256 share = shares[i];
            require(recipient != address(0), "Zero addr");
            totalShare += share;
            dist.push(RoyaltyInfo({recipient: recipient, share: share}));
        }

        require(totalShare == BASIS_POINTS, "Invalid share total");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "No ETH sent");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;
        require(len > 0, "No royalties");

        for (uint256 i; i < len; ++i) {
            RoyaltyInfo storage r = dist[i];
            uint256 payout = (amount * r.share) / BASIS_POINTS;
            (bool success, ) = r.recipient.call{value: payout}("");
            require(success, "Transfer failed");
        }

        emit RoyaltiesPaid(contentId, amount);
    }

    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i; i < len; ++i) {
            RoyaltyInfo storage r = dist[i];
            recipients[i] = r.recipient;
            shares[i] = r.share;
        }
    }

    function updateRoyaltyRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "Zero addr");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        for (uint256 i; i < len; ++i) {
            RoyaltyInfo storage r = dist[i];
            if (r.recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Not authorized");
                r.recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
        }

        revert("Old recipient not found");
    }

    receive() external payable {
        revert("Use payRoyalties");
    }
}
