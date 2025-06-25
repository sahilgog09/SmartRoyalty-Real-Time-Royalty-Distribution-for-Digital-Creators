// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    /// @dev Basis points denominator (100% = 10000)
    uint256 public constant BASIS_POINTS = 10_000;

    /// @dev Represents a royalty recipient and their share
    struct RoyaltyInfo {
        address recipient;
        uint256 share; // in basis points
    }

    /// @dev Maps content ID to its royalty distribution
    mapping(uint256 => RoyaltyInfo[]) private royalties;

    /// @notice Emitted when royalties are set for a content ID
    event RoyaltiesSet(uint256 indexed contentId);

    /// @notice Emitted when royalty payment is distributed
    event RoyaltiesPaid(uint256 indexed contentId, uint256 amount);

    /**
     * @notice Configure royalties for a given content ID
     * @param contentId Unique identifier for the content
     * @param recipients Array of recipient addresses
     * @param shares Corresponding shares in basis points (must sum to 10000)
     */
    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external {
        uint256 count = recipients.length;
        require(count == shares.length, "Mismatched input lengths");
        require(count > 0, "At least one recipient required");

        uint256 total = 0;
        for (uint256 i = 0; i < count; ) {
            require(recipients[i] != address(0), "Invalid recipient");
            total += shares[i];
            unchecked { ++i; }
        }

        require(total == BASIS_POINTS, "Total shares must equal 10000");

        delete royalties[contentId];

        for (uint256 i = 0; i < count; ) {
            royalties[contentId].push(RoyaltyInfo({
                recipient: recipients[i],
                share: shares[i]
            }));
            unchecked { ++i; }
        }

        emit RoyaltiesSet(contentId);
    }

    /**
     * @notice Pay royalties for a given content ID
     * @param contentId Unique identifier for the content
     */
    function payRoyalties(uint256 contentId) external payable {
        require(msg.value > 0, "No payment sent");

        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 count = dist.length;
        require(count > 0, "No royalty configuration");

        for (uint256 i = 0; i < count; ) {
            uint256 amount = (msg.value * dist[i].share) / BASIS_POINTS;
            payable(dist[i].recipient).transfer(amount);
            unchecked { ++i; }
        }

        emit RoyaltiesPaid(contentId, msg.value);
    }

    /**
     * @notice View the royalty configuration for a content ID
     * @param contentId Unique identifier for the content
     * @return recipients List of recipient addresses
     * @return shares List of their corresponding shares
     */
    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        RoyaltyInfo[] storage dist = royalties[contentId];
        uint256 count = dist.length;

        recipients = new address[](count);
        shares = new uint256[](count);

        for (uint256 i = 0; i < count; ) {
            recipients[i] = dist[i].recipient;
            shares[i] = dist[i].share;
            unchecked { ++i; }
        }
    }
}
