// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartRoyalty {
    /// @notice Basis point denominator (100% = 10000)
    uint256 public constant MAX_BASIS_POINTS = 10000;

    /// @notice Stores royalty recipient and their share in basis points
    struct RoyaltyRecipient {
        address recipient;
        uint256 share;
    }

    /// @dev Maps content ID to its list of royalty recipients
    mapping(uint256 => RoyaltyRecipient[]) private contentRoyalties;

    /// @notice Emitted when royalties are configured for a content ID
    event RoyaltyConfigured(uint256 indexed contentId);

    /// @notice Emitted when royalty is paid for a content ID
    event RoyaltyPaid(uint256 indexed contentId, uint256 amount);

    /**
     * @notice Sets royalty recipients and their shares for a content ID
     * @param contentId The unique ID of the content
     * @param recipients Array of recipient addresses
     * @param shares Array of shares in basis points (must sum to 10000)
     */
    function configureRoyalty(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external {
        uint256 len = recipients.length;
        require(len == shares.length, "Mismatch in array lengths");
        require(len > 0, "No recipients provided");

        uint256 totalShare = 0;

        for (uint256 i = 0; i < len; ) {
            require(recipients[i] != address(0), "Recipient cannot be zero address");
            totalShare += shares[i];
            unchecked { ++i; }
        }

        require(totalShare == MAX_BASIS_POINTS, "Total shares must be 10000");

        // Clear previous royalty configuration
        delete contentRoyalties[contentId];

        for (uint256 i = 0; i < len; ) {
            contentRoyalties[contentId].push(
                RoyaltyRecipient({recipient: recipients[i], share: shares[i]})
            );
            unchecked { ++i; }
        }

        emit RoyaltyConfigured(contentId);
    }

    /**
     * @notice Pays out royalties based on the configuration for a content ID
     * @param contentId The ID of the content
     */
    function payRoyalty(uint256 contentId) external payable {
        require(msg.value > 0, "No Ether sent");

        RoyaltyRecipient[] storage recipients = contentRoyalties[contentId];
        uint256 len = recipients.length;
        require(len > 0, "No royalty recipients configured");

        for (uint256 i = 0; i < len; ) {
            uint256 payment = (msg.value * recipients[i].share) / MAX_BASIS_POINTS;
            payable(recipients[i].recipient).transfer(payment);
            unchecked { ++i; }
        }

        emit RoyaltyPaid(contentId, msg.value);
    }

    /**
     * @notice Returns royalty recipients and their shares for a given content ID
     * @param contentId The ID of the content
     * @return recipients Array of recipient addresses
     * @return shares Array of recipient shares
     */
    function getRoyaltyRecipients(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        RoyaltyRecipient[] storage royalties = contentRoyalties[contentId];
        uint256 len = royalties.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i = 0; i < len; ) {
            recipients[i] = royalties[i].recipient;
            shares[i] = royalties[i].share;
            unchecked { ++i; }
        }
    }
}
