// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SmartRoyalty is Ownable {
    uint256 public constant BASIS_POINTS = 10_000;

    struct Royalty {
        address recipient;
        uint96 share; // Storage efficient
    }

    mapping(uint256 => Royalty[]) private royalties;

    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesPaid(uint256 indexed contentId, uint256 totalAmount);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);

    modifier validRoyaltyInput(address[] calldata recipients, uint256[] calldata shares) {
        require(recipients.length > 0 && recipients.length == shares.length, "Invalid input lengths");
        _;
    }

    /**
     * @notice Set or update royalty recipients for a specific content ID.
     * @dev Only callable by the contract owner.
     */
    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external onlyOwner validRoyaltyInput(recipients, shares) {
        delete royalties[contentId];
        Royalty[] storage dist = royalties[contentId];

        uint256 totalShare;
        uint256 len = recipients.length;

        for (uint256 i; i < len; ) {
            address r = recipients[i];
            uint256 s = shares[i];

            require(r != address(0), "Zero address");
            require(s > 0 && s <= BASIS_POINTS, "Invalid share");

            dist.push(Royalty(r, uint96(s)));
            totalShare += s;

            unchecked { ++i; }
        }

        require(totalShare == BASIS_POINTS, "Total shares must equal 10000");
        emit RoyaltiesSet(contentId);
    }

    /**
     * @notice Distributes sent ETH to the royalty recipients.
     */
    function payRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "No ETH sent");

        Royalty[] storage dist = royalties[contentId];
        uint256 len = dist.length;
        require(len > 0, "Royalties not configured");

        for (uint256 i; i < len; ) {
            Royalty storage r = dist[i];
            uint256 payout = (amount * r.share) / BASIS_POINTS;

            (bool success, ) = r.recipient.call{value: payout}("");
            require(success, "Transfer failed");

            unchecked { ++i; }
        }

        emit RoyaltiesPaid(contentId, amount);
    }

    /**
     * @notice Returns the royalty recipients and their shares.
     */
    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        Royalty[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i; i < len; ) {
            Royalty storage r = dist[i];
            recipients[i] = r.recipient;
            shares[i] = r.share;

            unchecked { ++i; }
        }
    }

    /**
     * @notice Updates a recipient's address for a content ID.
     * @dev Only callable by the current recipient or contract owner.
     */
    function updateRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        require(newRecipient != address(0), "Zero new address");

        Royalty[] storage dist = royalties[contentId];
        uint256 len = dist.length;

        for (uint256 i; i < len; ) {
            if (dist[i].recipient == oldRecipient) {
                require(msg.sender == oldRecipient || msg.sender == owner(), "Not authorized");
                dist[i].recipient = newRecipient;

                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
            unchecked { ++i; }
        }

        revert("Recipient not found");
    }

    /**
     * @notice Prevents direct ETH transfers.
     */
    receive() external payable {
        revert("Use payRoyalties()");
    }
}
