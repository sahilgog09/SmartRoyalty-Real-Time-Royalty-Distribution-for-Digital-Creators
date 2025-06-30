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

    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external {
        uint256 len = recipients.length;
        require(len == shares.length && len > 0, "Invalid input");

        delete royalties[contentId]; // clear existing royalties

        uint256 totalShare;
        RoyaltyInfo[] storage dist = royalties[contentId];

        for (uint256 i = 0; i < len; ++i) {
            address recipient = recipients[i];
            uint256 share = shares[i];
            require(recipient != address(0), "Zero address");
            totalShare += share;
            dist.push(RoyaltyInfo({recipient: recipient, share: share}));
        }

        require(totalShare == BASIS_POINTS, "Total ≠ 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 value = msg.value;
        require(value > 0, "No payment");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;
        require(len > 0, "No royalties set");

        for (uint256 i = 0; i < len; ++i) {
            RoyaltyInfo storage r = dist[i];
            uint256 payout = (value * r.share) / BASIS_POINTS;
            (bool success, ) = r.recipient.call{value: payout}("");
            require(success, "Transfer failed");
        }

        emit RoyaltiesPaid(contentId, value);
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
        require(newRecipient != address(0), "Zero address");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        for (uint256 i = 0; i < len; ++i) {
            if (dist[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Unauthorized");
                dist[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
        }

        revert("Recipient not found");
    }
