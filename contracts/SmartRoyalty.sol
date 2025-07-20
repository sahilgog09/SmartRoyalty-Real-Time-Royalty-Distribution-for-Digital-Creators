// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    uint256 public constant BASIS_POINTS = 10_000;

    struct RoyaltyInfo {
        address recipient;
        uint96 share; // Smaller type to save gas
    }

    mapping(uint256 => RoyaltyInfo[]) private royalties;

    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesPaid(uint256 indexed contentId, uint256 amount);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validInput(address[] calldata recipients, uint256[] calldata shares) {
        require(recipients.length == shares.length && recipients.length > 0, "Invalid input");
        _;
    }

    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external validInput(recipients, shares) {
        delete royalties[contentId];
        RoyaltyInfo[] storage dist = royalties[contentId];

        uint256 totalShare;
        uint256 len = recipients.length;

        for (uint256 i; i < len; ) {
            address recipient = recipients[i];
            uint256 share = shares[i];
            require(recipient != address(0), "Zero address");
            require(share <= BASIS_POINTS, "Share too high");

            totalShare += share;
            dist.push(RoyaltyInfo({recipient: recipient, share: uint96(share)}));

            unchecked { ++i; }
        }

        require(totalShare == BASIS_POINTS, "Total share ≠ 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "No payment");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;
        require(len > 0, "No royalties");

        for (uint256 i; i < len; ) {
            RoyaltyInfo storage r = dist[i];
            uint256 payout = (amount * r.share) / BASIS_POINTS;

            (bool sent, ) = r.recipient.call{value: payout}("");
            require(sent, "Transfer failed");

            unchecked { ++i; }
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

        for (uint256 i; i < len; ) {
            RoyaltyInfo storage r = dist[i];
            recipients[i] = r.recipient;
            shares[i] = r.share;
            unchecked { ++i; }
        }
    }

    function updateRoyaltyRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "New recipient zero");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        for (uint256 i; i < len; ) {
            if (dist[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Unauthorized");
                dist[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
            unchecked { ++i; }
        }

        revert("Recipient not found");
    }

    receive() external payable {
        revert("Use payRoyalties");
    }
}
