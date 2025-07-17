// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    uint256 public constant BASIS_POINTS = 10_000;

    struct RoyaltyInfo {
        address recipient;
        uint256 share;
    }

    mapping(uint256 => RoyaltyInfo[]) private royalties;

    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesPaid(uint256 indexed contentId, uint256 amount);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validRoyaltyInput(address[] calldata recipients, uint256[] calldata shares) {
        uint256 len = recipients.length;
        require(len > 0 && len == shares.length, "Input length mismatch or empty");
        _;
    }

    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external validRoyaltyInput(recipients, shares) {
        delete royalties[contentId];

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 totalShare;

        for (uint256 i = 0; i < recipients.length; ++i) {
            address recipient = recipients[i];
            uint256 share = shares[i];
            require(recipient != address(0), "Recipient cannot be zero");
            totalShare += share;
            dist.push(RoyaltyInfo(recipient, share));
        }

        require(totalShare == BASIS_POINTS, "Total share must equal 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "No payment received");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;
        require(len > 0, "Royalties not set");

        for (uint256 i = 0; i < len; ++i) {
            RoyaltyInfo storage r = dist[i];
            uint256 payout = (amount * r.share) / BASIS_POINTS;
            (bool success, ) = r.recipient.call{value: payout}("");
            require(success, "Royalty transfer failed");
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

        for (uint256 i = 0; i < len; ++i) {
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
        require(newRecipient != address(0), "New recipient cannot be zero");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        for (uint256 i = 0; i < len; ++i) {
            if (dist[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Only current recipient can update");
                dist[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
        }

        revert("Old recipient not found");
    }

    // Optional: catch accidental ETH transfers
    receive() external payable {
        revert("Use payRoyalties to send ETH");
    }
}
