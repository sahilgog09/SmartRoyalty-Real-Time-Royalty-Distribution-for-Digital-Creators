// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    uint256 public constant BASIS_POINTS = 10_000;

    struct RoyaltyInfo {
        address recipient;
        uint96 share; // Gas-efficient size
    }

    mapping(uint256 => RoyaltyInfo[]) private royalties;

    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesPaid(uint256 indexed contentId, uint256 amount);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validRoyaltyInput(address[] calldata recipients, uint256[] calldata shares) {
        uint256 len = recipients.length;
        require(len > 0 && len == shares.length, "Invalid input lengths");
        _;
    }

    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external validRoyaltyInput(recipients, shares) {
        delete royalties[contentId];
        RoyaltyInfo[] storage list = royalties[contentId];

        uint256 total;
        for (uint256 i; i < recipients.length; ) {
            address r = recipients[i];
            uint256 s = shares[i];
            require(r != address(0), "Zero recipient");
            require(s <= BASIS_POINTS, "Share overflow");

            total += s;
            list.push(RoyaltyInfo(r, uint96(s)));

            unchecked { ++i; }
        }

        require(total == BASIS_POINTS, "Shares must total 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "No ETH sent");

        RoyaltyInfo[] storage list = royalties[contentId];
        uint256 len = list.length;
        require(len > 0, "No royalty data");

        for (uint256 i; i < len; ) {
            RoyaltyInfo storage r = list[i];
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
        RoyaltyInfo[] storage list = royalties[contentId];
        uint256 len = list.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i; i < len; ) {
            RoyaltyInfo storage r = list[i];
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
        require(newRecipient != address(0), "Zero address");

        RoyaltyInfo[] storage list = royalties[contentId];
        uint256 len = list.length;

        for (uint256 i; i < len; ) {
            if (list[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient, "Not authorized");
                list[i].recipient = newRecipient;
                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
            unchecked { ++i; }
        }

        revert("Recipient not found");
    }

    receive() external payable {
        revert("Use payRoyalties()");
    }
}
