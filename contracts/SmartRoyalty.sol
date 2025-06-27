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

    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external {
        uint256 count = recipients.length;
        require(count == shares.length, "Mismatched input lengths");
        require(count > 0, "At least one recipient required");

        uint256 totalShare;
        for (uint256 i = 0; i < count; ++i) {
            address recipient = recipients[i];
            uint256 share = shares[i];
            require(recipient != address(0), "Invalid recipient");
            totalShare += share;
        }
        require(totalShare == BASIS_POINTS, "Total shares must equal 10000");

        delete royalties[contentId];
        RoyaltyInfo[] storage list = royalties[contentId];
        for (uint256 i = 0; i < count; ++i) {
            list.push(RoyaltyInfo(recipients[i], shares[i]));
        }

        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "No payment sent");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 count = dist.length;
        require(count > 0, "No royalty configuration");

        for (uint256 i = 0; i < count; ++i) {
            uint256 shareAmount = (amount * dist[i].share) / BASIS_POINTS;
            payable(dist[i].recipient).transfer(shareAmount);
        }

        emit RoyaltiesPaid(contentId, amount);
    }

    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 count = dist.length;

        recipients = new address[](count);
        shares = new uint256[](count);

        for (uint256 i = 0; i < count; ++i) {
            recipients[i] = dist[i].recipient;
            shares[i] = dist[i].share;
        }
    }

    function updateRoyaltyRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "Invalid new recipient");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 count = dist.length;
        require(count > 0, "No royalty configuration");

        for (uint256 i = 0; i < count; ++i) {
            if (dist[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Only current recipient can update");
                dist[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
        }

        revert("Recipient not found");
    }
}
