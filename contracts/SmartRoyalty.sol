// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    uint256 public constant BASIS_POINTS = 10_000;

    struct RoyaltyInfo {
        address recipient;
        uint96 share; // Efficient: fits 3 per storage slot
    }

    mapping(uint256 => RoyaltyInfo[]) private _royalties;

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
        delete _royalties[contentId];

        RoyaltyInfo[] storage entries = _royalties[contentId];
        uint256 totalShare;

        for (uint256 i; i < recipients.length; ) {
            address recipient = recipients[i];
            uint256 share = shares[i];
            require(recipient != address(0), "Zero address");
            require(share > 0 && share <= BASIS_POINTS, "Invalid share");

            totalShare += share;
            entries.push(RoyaltyInfo(recipient, uint96(share)));

            unchecked { ++i; }
        }

        require(totalShare == BASIS_POINTS, "Total ≠ 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 value = msg.value;
        require(value > 0, "Zero payment");

        RoyaltyInfo[] storage entries = _royalties[contentId];
        uint256 len = entries.length;
        require(len > 0, "Royalties not set");

        for (uint256 i; i < len; ) {
            RoyaltyInfo storage r = entries[i];
            uint256 payout = (value * r.share) / BASIS_POINTS;

            // send funds
            (bool success, ) = r.recipient.call{value: payout}("");
            require(success, "Transfer failed");

            unchecked { ++i; }
        }

        emit RoyaltiesPaid(contentId, value);
    }

    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        RoyaltyInfo[] storage entries = _royalties[contentId];
        uint256 len = entries.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i; i < len; ) {
            recipients[i] = entries[i].recipient;
            shares[i] = entries[i].share;
            unchecked { ++i; }
        }
    }

    function updateRoyaltyRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "New is zero");

        RoyaltyInfo[] storage entries = _royalties[contentId];
        uint256 len = entries.length;

        for (uint256 i; i < len; ) {
            if (entries[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Unauthorized");
                entries[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
            unchecked { ++i; }
        }

        revert("Old recipient not found");
    }

    receive() external payable {
        revert("Use payRoyalties()");
    }
}
