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

        uint256 total;
        delete royalties[contentId]; // gas-efficient way to overwrite

        RoyaltyInfo[] storage dist = royalties[contentId];
        for (uint256 i; i < len; ++i) {
            address r = recipients[i];
            uint256 s = shares[i];
            require(r != address(0), "Zero address");
            total += s;
            dist.push(RoyaltyInfo(r, s));
        }

        require(total == BASIS_POINTS, "Total ≠ 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        require(msg.value > 0, "No payment");

        RoyaltyInfo[] storage dist = royalties[contentId];
        require(dist.length > 0, "No royalties set");

        uint256 value = msg.value;
        for (uint256 i; i < dist.length; ++i) {
            uint256 payout = (value * dist[i].share) / BASIS_POINTS;
            (bool success, ) = dist[i].recipient.call{value: payout}("");
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
        require(newRecipient != address(0), "Zero address");

        RoyaltyInfo[] storage dist = royalties[contentId];

        for (uint256 i; i < dist.length; ++i) {
            if (dist[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Unauthorized");
                dist[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
        }

        revert("Recipient not found");
    }
}
