// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SmartRoyalty is Ownable {
    uint256 public constant BASIS_POINTS = 10_000;

    struct RoyaltyInfo {
        address recipient;
        uint96 share;
    }



    mapping(uint256 => RoyaltyInfo[]) private _royalties;

    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesPaid(uint256 indexed contentId, uint256 amount);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validInput(address[] calldata recipients, uint256[] calldata shares) {
        uint256 len = recipients.length;
        require(len > 0 && len == shares.length, "Invalid input lengths");
        _;
    }

    // Only contract owner can set royalties
    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external onlyOwner validInput(recipients, shares) {
        delete _royalties[contentId];
        RoyaltyInfo[] storage entries = _royalties[contentId];

        uint256 total;
        for (uint256 i; i < recipients.length; ) {
            address r = recipients[i];
            uint256 s = shares[i];
            require(r != address(0), "Zero address");
            require(s > 0 && s <= BASIS_POINTS, "Invalid share");

            total += s;
            entries.push(RoyaltyInfo(r, uint96(s)));

            unchecked { ++i; }
        }

        require(total == BASIS_POINTS, "Total share ≠ 10000");
        emit RoyaltiesSet(contentId);
    }

    function payRoyalties(uint256 contentId) external payable {
        uint256 value = msg.value;
        require(value > 0, "No ETH sent");

        RoyaltyInfo[] storage entries = _royalties[contentId];
        uint256 len = entries.length;
        require(len > 0, "Royalties not set");

        for (uint256 i; i < len; ) {
            RoyaltyInfo storage r = entries[i];
            uint256 payout = (value * r.share) / BASIS_POINTS;

            (bool sent, ) = r.recipient.call{value: payout}("");
            require(sent, "Transfer failed");

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

    // Only owner or oldRecipient can update recipient
    function updateRoyaltyRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "Zero new address");

        RoyaltyInfo[] storage entries = _royalties[contentId];
        uint256 len = entries.length;

        for (uint256 i; i < len; ) {
            if (entries[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient || msg.sender == owner(), "Unauthorized");
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
