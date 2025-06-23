// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title SmartRoyalty
 * @notice Splits incoming Ether among pre-configured royalty recipients.
 * @dev Public interface is unchanged: same events, funcs & mapping.
 */
contract SmartRoyalty {
    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error InputLengthMismatch();
    error ZeroAddress();
    error InvalidTotalShare();
    error NoEtherSent();
    error RecipientsNotConfigured();

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */
    uint256 private constant _BASIS_POINTS = 10_000; // 100 %

    /* -------------------------------------------------------------------------- */
    /*                               Data Structures                              */
    /* -------------------------------------------------------------------------- */
    struct RoyaltyRecipient {
        address recipient;
        uint256 share; // in basis points (10 000 = 100 %)
    }

    /// @dev Same public getter as before (contentRoyalties(contentId, idx))
    mapping(uint256 => RoyaltyRecipient[]) public contentRoyalties;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event RoyaltyConfigured(uint256 indexed contentId);
    event RoyaltyPaid(uint256 indexed contentId, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                              External Logic                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Configure the royalty split for a given contentId.
     * @dev Reverts if input arrays differ in length, contain zero addresses,
     *      or if the total share ≠ 10 000 bps.
     */
    function configureRoyalty(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external {
        uint256 n = recipients.length;
        if (n != shares.length) revert InputLengthMismatch();

        // Clear any previous config
        delete contentRoyalties[contentId];

        uint256 totalShare;
        for (uint256 i; i < n; ) {
            address receiver = recipients[i];
            if (receiver == address(0)) revert ZeroAddress();

            uint256 shareBps = shares[i];
            contentRoyalties[contentId].push(
                RoyaltyRecipient({recipient: receiver, share: shareBps})
            );

            totalShare += shareBps;
            unchecked { ++i; }
        }

        if (totalShare != _BASIS_POINTS) revert InvalidTotalShare();

        emit RoyaltyConfigured(contentId);
    }

    /**
     * @notice Split the incoming Ether among the configured recipients.
     */
    function payRoyalty(uint256 contentId) external payable {
        if (msg.value == 0) revert NoEtherSent();

        RoyaltyRecipient[] storage list = contentRoyalties[contentId];
        uint256 n = list.length;
        if (n == 0) revert RecipientsNotConfigured();

        for (uint256 i; i < n; ) {
            RoyaltyRecipient storage info = list[i];
            uint256 payment = (msg.value * info.share) / _BASIS_POINTS;
            payable(info.recipient).transfer(payment);
            unchecked { ++i; }
        }

        emit RoyaltyPaid(contentId, msg.value);
    }

    /**
     * @notice View helper returning all recipients and shares for a contentId.
     */
    function getRoyaltyRecipients(
        uint256 contentId
    )
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        RoyaltyRecipient[] storage list = contentRoyalties[contentId];
        uint256 n = list.length;

        recipients = new address[](n);
        shares     = new uint256[](n);

        for (uint256 i; i < n; ) {
            RoyaltyRecipient storage info = list[i];
            recipients[i] = info.recipient;
            shares[i]     = info.share;
            unchecked { ++i; }
        }
    }
}
