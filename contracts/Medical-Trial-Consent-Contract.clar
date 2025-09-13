(define-data-var contract-owner principal tx-sender)
(define-data-var next-trial-id uint u1)
(define-data-var next-consent-id uint u1)
(define-data-var next-credential-id uint u1)
(define-data-var current-block-height uint u1)
(define-data-var total-escrow-balance uint u0)

(define-map trials
    { trial-id: uint }
    {
        organizer: principal,
        title: (string-ascii 128),
        description: (string-ascii 512),
        start-block: uint,
        end-block: uint,
        max-participants: uint,
        current-participants: uint,
        is-active: bool,
        required-age: uint,
        compensation: uint,
        created-at: uint,
        escrow-deposited: bool,
        escrow-amount: uint,
    }
)

(define-map consents
    { consent-id: uint }
    {
        participant: principal,
        trial-id: uint,
        consent-given: bool,
        consent-timestamp: uint,
        withdrawal-timestamp: (optional uint),
        participant-age: uint,
        emergency-contact: (string-ascii 64),
        medical-history: (string-ascii 256),
        is-withdrawn: bool,
        compensation-claimed: bool,
    }
)

(define-map participant-trials
    {
        participant: principal,
        trial-id: uint,
    }
    {
        consent-id: uint,
        status: (string-ascii 16),
    }
)

(define-map trial-participants
    {
        trial-id: uint,
        participant: principal,
    }
    {
        consent-id: uint,
        joined-at: uint,
    }
)

(define-map participant-profiles
    { participant: principal }
    {
        full-name: (string-ascii 64),
        date-of-birth: uint,
        contact-info: (string-ascii 128),
        created-at: uint,
        total-trials: uint,
    }
)

(define-map trial-analytics
    { trial-id: uint }
    {
        total-enrolled: uint,
        total-withdrawn: uint,
        total-completed: uint,
        completion-rate: uint,
        withdrawal-rate: uint,
        compensation-paid: uint,
        average-participation-duration: uint,
        last-updated: uint,
    }
)

(define-map participant-credentials
    {
        participant: principal,
        credential-id: uint,
    }
    {
        credential-type: (string-ascii 32),
        credential-number: (string-ascii 64),
        issuing-authority: (string-ascii 64),
        issued-date: uint,
        expiration-date: uint,
        verification-status: (string-ascii 16),
        verified-by: (optional principal),
        verified-at: (optional uint),
        document-hash: (string-ascii 64),
        is-active: bool,
    }
)

(define-map trial-credential-requirements
    {
        trial-id: uint,
        credential-type: (string-ascii 32),
    }
    {
        required: bool,
        minimum-years-valid: uint,
        specific-authorities: (list 5 (string-ascii 64)),
        added-by: principal,
        added-at: uint,
    }
)

(define-map credential-verifiers
    { verifier: principal }
    {
        authorized: bool,
        credential-types: (list 10 (string-ascii 32)),
        added-by: principal,
        added-at: uint,
    }
)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TRIAL-NOT-FOUND (err u101))
(define-constant ERR-TRIAL-INACTIVE (err u102))
(define-constant ERR-TRIAL-FULL (err u103))
(define-constant ERR-ALREADY-CONSENTED (err u104))
(define-constant ERR-NO-CONSENT-FOUND (err u105))
(define-constant ERR-ALREADY-WITHDRAWN (err u106))
(define-constant ERR-TRIAL-ENDED (err u107))
(define-constant ERR-INVALID-AGE (err u108))
(define-constant ERR-INVALID-PARTICIPANT (err u109))
(define-constant ERR-TRIAL-NOT-STARTED (err u110))
(define-constant ERR-INSUFFICIENT-FUNDS (err u111))
(define-constant ERR-ESCROW-ALREADY-DEPOSITED (err u112))
(define-constant ERR-ESCROW-NOT-DEPOSITED (err u113))
(define-constant ERR-COMPENSATION-ALREADY-CLAIMED (err u114))
(define-constant ERR-INVALID-AMOUNT (err u115))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u116))
(define-constant ERR-CREDENTIAL-EXPIRED (err u117))
(define-constant ERR-NOT-AUTHORIZED-VERIFIER (err u118))
(define-constant ERR-CREDENTIAL-ALREADY-EXISTS (err u119))
(define-constant ERR-INVALID-CREDENTIAL-TYPE (err u120))
(define-constant ERR-CREDENTIAL-NOT-VERIFIED (err u121))
(define-constant ERR-MISSING-REQUIRED-CREDENTIALS (err u122))

(define-private (get-current-block)
    (var-get current-block-height)
)

(define-private (increment-block)
    (var-set current-block-height (+ (var-get current-block-height) u1))
)

(define-public (create-trial
        (title (string-ascii 128))
        (description (string-ascii 512))
        (duration-blocks uint)
        (max-participants uint)
        (required-age uint)
        (compensation uint)
    )
    (let (
            (trial-id (var-get next-trial-id))
            (current-height (get-current-block))
            (start-block (+ current-height u1))
            (end-block (+ start-block duration-blocks))
        )
        (asserts! (> max-participants u0) ERR-NOT-AUTHORIZED)
        (asserts! (>= required-age u18) ERR-INVALID-AGE)
        (asserts! (> duration-blocks u0) ERR-NOT-AUTHORIZED)

        (map-set trials { trial-id: trial-id } {
            organizer: tx-sender,
            title: title,
            description: description,
            start-block: start-block,
            end-block: end-block,
            max-participants: max-participants,
            current-participants: u0,
            is-active: true,
            required-age: required-age,
            compensation: compensation,
            created-at: current-height,
            escrow-deposited: false,
            escrow-amount: u0,
        })

        (var-set next-trial-id (+ trial-id u1))
        (ok trial-id)
    )
)

(define-public (create-participant-profile
        (full-name (string-ascii 64))
        (date-of-birth uint)
        (contact-info (string-ascii 128))
    )
    (begin
        (map-set participant-profiles { participant: tx-sender } {
            full-name: full-name,
            date-of-birth: date-of-birth,
            contact-info: contact-info,
            created-at: (get-current-block),
            total-trials: u0,
        })
        (ok true)
    )
)

(define-public (give-consent
        (trial-id uint)
        (participant-age uint)
        (emergency-contact (string-ascii 64))
        (medical-history (string-ascii 256))
    )
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
            (consent-id (var-get next-consent-id))
            (current-block (get-current-block))
        )
        (asserts! (get is-active trial) ERR-TRIAL-INACTIVE)
        (asserts! (>= current-block (get start-block trial))
            ERR-TRIAL-NOT-STARTED
        )
        (asserts! (< current-block (get end-block trial)) ERR-TRIAL-ENDED)
        (asserts!
            (< (get current-participants trial) (get max-participants trial))
            ERR-TRIAL-FULL
        )
        (asserts! (>= participant-age (get required-age trial)) ERR-INVALID-AGE)
        (asserts!
            (is-none (map-get? participant-trials {
                participant: tx-sender,
                trial-id: trial-id,
            }))
            ERR-ALREADY-CONSENTED
        )

        (map-set consents { consent-id: consent-id } {
            participant: tx-sender,
            trial-id: trial-id,
            consent-given: true,
            consent-timestamp: current-block,
            withdrawal-timestamp: none,
            participant-age: participant-age,
            emergency-contact: emergency-contact,
            medical-history: medical-history,
            is-withdrawn: false,
            compensation-claimed: false,
        })

        (map-set participant-trials {
            participant: tx-sender,
            trial-id: trial-id,
        } {
            consent-id: consent-id,
            status: "consented",
        })

        (map-set trial-participants {
            trial-id: trial-id,
            participant: tx-sender,
        } {
            consent-id: consent-id,
            joined-at: current-block,
        })

        (map-set trials { trial-id: trial-id }
            (merge trial { current-participants: (+ (get current-participants trial) u1) })
        )

        (match (map-get? participant-profiles { participant: tx-sender })
            profile (map-set participant-profiles { participant: tx-sender }
                (merge profile { total-trials: (+ (get total-trials profile) u1) })
            )
            true
        )

        (var-set next-consent-id (+ consent-id u1))
        (ok consent-id)
    )
)

(define-public (withdraw-consent (trial-id uint))
    (let (
            (participant-trial (unwrap!
                (map-get? participant-trials {
                    participant: tx-sender,
                    trial-id: trial-id,
                })
                ERR-NO-CONSENT-FOUND
            ))
            (consent-id (get consent-id participant-trial))
            (consent (unwrap! (map-get? consents { consent-id: consent-id })
                ERR-NO-CONSENT-FOUND
            ))
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
        )
        (asserts! (not (get is-withdrawn consent)) ERR-ALREADY-WITHDRAWN)
        (asserts! (get is-active trial) ERR-TRIAL-INACTIVE)

        (map-set consents { consent-id: consent-id }
            (merge consent {
                is-withdrawn: true,
                withdrawal-timestamp: (some (get-current-block)),
            })
        )

        (map-set participant-trials {
            participant: tx-sender,
            trial-id: trial-id,
        }
            (merge participant-trial { status: "withdrawn" })
        )

        (map-set trials { trial-id: trial-id }
            (merge trial { current-participants: (- (get current-participants trial) u1) })
        )

        (ok true)
    )
)

(define-public (deactivate-trial (trial-id uint))
    (let ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get organizer trial)) ERR-NOT-AUTHORIZED)

        (map-set trials { trial-id: trial-id } (merge trial { is-active: false }))
        (ok true)
    )
)

(define-public (extend-trial
        (trial-id uint)
        (additional-blocks uint)
    )
    (let ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get organizer trial)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active trial) ERR-TRIAL-INACTIVE)

        (map-set trials { trial-id: trial-id }
            (merge trial { end-block: (+ (get end-block trial) additional-blocks) })
        )
        (ok true)
    )
)

(define-public (deposit-escrow (trial-id uint))
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
            (required-amount (* (get compensation trial) (get max-participants trial)))
        )
        (asserts! (is-eq tx-sender (get organizer trial)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get escrow-deposited trial)) ERR-ESCROW-ALREADY-DEPOSITED)
        (asserts! (> required-amount u0) ERR-INVALID-AMOUNT)

        (try! (stx-transfer? required-amount tx-sender (as-contract tx-sender)))

        (map-set trials { trial-id: trial-id }
            (merge trial {
                escrow-deposited: true,
                escrow-amount: required-amount,
            })
        )

        (var-set total-escrow-balance
            (+ (var-get total-escrow-balance) required-amount)
        )
        (ok required-amount)
    )
)

(define-public (claim-compensation (trial-id uint))
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
            (participant-trial (unwrap!
                (map-get? participant-trials {
                    participant: tx-sender,
                    trial-id: trial-id,
                })
                ERR-NO-CONSENT-FOUND
            ))
            (consent-id (get consent-id participant-trial))
            (consent (unwrap! (map-get? consents { consent-id: consent-id })
                ERR-NO-CONSENT-FOUND
            ))
            (compensation-amount (get compensation trial))
            (current-block (get-current-block))
        )
        (asserts! (get escrow-deposited trial) ERR-ESCROW-NOT-DEPOSITED)
        (asserts! (>= current-block (get end-block trial)) ERR-TRIAL-NOT-STARTED)
        (asserts! (get consent-given consent) ERR-NO-CONSENT-FOUND)
        (asserts! (not (get is-withdrawn consent)) ERR-ALREADY-WITHDRAWN)
        (asserts! (not (get compensation-claimed consent))
            ERR-COMPENSATION-ALREADY-CLAIMED
        )

        (try! (as-contract (stx-transfer? compensation-amount tx-sender tx-sender)))

        (map-set consents { consent-id: consent-id }
            (merge consent { compensation-claimed: true })
        )

        (var-set total-escrow-balance
            (- (var-get total-escrow-balance) compensation-amount)
        )
        (ok compensation-amount)
    )
)

(define-public (refund-escrow (trial-id uint))
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
            (current-block (get-current-block))
            (escrow-amount (get escrow-amount trial))
            (participants-count (get current-participants trial))
            (compensation-per-participant (get compensation trial))
            (used-amount (* participants-count compensation-per-participant))
            (refund-amount (- escrow-amount used-amount))
        )
        (asserts! (is-eq tx-sender (get organizer trial)) ERR-NOT-AUTHORIZED)
        (asserts! (get escrow-deposited trial) ERR-ESCROW-NOT-DEPOSITED)
        (asserts! (>= current-block (get end-block trial)) ERR-TRIAL-NOT-STARTED)
        (asserts! (> refund-amount u0) ERR-INVALID-AMOUNT)

        (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))

        (map-set trials { trial-id: trial-id }
            (merge trial { escrow-amount: used-amount })
        )

        (var-set total-escrow-balance
            (- (var-get total-escrow-balance) refund-amount)
        )
        (ok refund-amount)
    )
)

(define-public (advance-block)
    (begin
        (increment-block)
        (ok (get-current-block))
    )
)

(define-public (submit-credential
        (credential-type (string-ascii 32))
        (credential-number (string-ascii 64))
        (issuing-authority (string-ascii 64))
        (issued-date uint)
        (expiration-date uint)
        (document-hash (string-ascii 64))
    )
    (let (
            (credential-id (var-get next-credential-id))
            (current-block (get-current-block))
        )
        (asserts! (> expiration-date current-block) ERR-CREDENTIAL-EXPIRED)
        (asserts! (> expiration-date issued-date) ERR-INVALID-AMOUNT)
        (asserts!
            (is-none (map-get? participant-credentials {
                participant: tx-sender,
                credential-id: credential-id,
            }))
            ERR-CREDENTIAL-ALREADY-EXISTS
        )

        (map-set participant-credentials {
            participant: tx-sender,
            credential-id: credential-id,
        } {
            credential-type: credential-type,
            credential-number: credential-number,
            issuing-authority: issuing-authority,
            issued-date: issued-date,
            expiration-date: expiration-date,
            verification-status: "pending",
            verified-by: none,
            verified-at: none,
            document-hash: document-hash,
            is-active: true,
        })

        (var-set next-credential-id (+ credential-id u1))
        (ok credential-id)
    )
)

(define-public (verify-credential
        (participant principal)
        (credential-id uint)
        (verification-status (string-ascii 16))
    )
    (let (
            (credential (unwrap!
                (map-get? participant-credentials {
                    participant: participant,
                    credential-id: credential-id,
                })
                ERR-CREDENTIAL-NOT-FOUND
            ))
            (verifier (unwrap! (map-get? credential-verifiers { verifier: tx-sender })
                ERR-NOT-AUTHORIZED-VERIFIER
            ))
            (current-block (get-current-block))
        )
        (asserts! (get authorized verifier) ERR-NOT-AUTHORIZED-VERIFIER)
        (asserts! (> (get expiration-date credential) current-block)
            ERR-CREDENTIAL-EXPIRED
        )

        (map-set participant-credentials {
            participant: participant,
            credential-id: credential-id,
        }
            (merge credential {
                verification-status: verification-status,
                verified-by: (some tx-sender),
                verified-at: (some current-block),
            })
        )
        (ok true)
    )
)

(define-public (authorize-verifier
        (verifier principal)
        (credential-types (list 10 (string-ascii 32)))
    )
    (let ((current-block (get-current-block)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

        (map-set credential-verifiers { verifier: verifier } {
            authorized: true,
            credential-types: credential-types,
            added-by: tx-sender,
            added-at: current-block,
        })
        (ok true)
    )
)

(define-public (set-trial-credential-requirement
        (trial-id uint)
        (credential-type (string-ascii 32))
        (minimum-years-valid uint)
        (specific-authorities (list 5 (string-ascii 64)))
    )
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
            (current-block (get-current-block))
        )
        (asserts! (is-eq tx-sender (get organizer trial)) ERR-NOT-AUTHORIZED)

        (map-set trial-credential-requirements {
            trial-id: trial-id,
            credential-type: credential-type,
        } {
            required: true,
            minimum-years-valid: minimum-years-valid,
            specific-authorities: specific-authorities,
            added-by: tx-sender,
            added-at: current-block,
        })
        (ok true)
    )
)

(define-public (deactivate-credential (credential-id uint))
    (let ((credential (unwrap!
            (map-get? participant-credentials {
                participant: tx-sender,
                credential-id: credential-id,
            })
            ERR-CREDENTIAL-NOT-FOUND
        )))
        (map-set participant-credentials {
            participant: tx-sender,
            credential-id: credential-id,
        }
            (merge credential { is-active: false })
        )
        (ok true)
    )
)

(define-read-only (get-trial (trial-id uint))
    (map-get? trials { trial-id: trial-id })
)

(define-read-only (get-consent (consent-id uint))
    (map-get? consents { consent-id: consent-id })
)

(define-read-only (get-participant-consent
        (participant principal)
        (trial-id uint)
    )
    (match (map-get? participant-trials {
        participant: participant,
        trial-id: trial-id,
    })
        participant-trial (map-get? consents { consent-id: (get consent-id participant-trial) })
        none
    )
)

(define-read-only (get-participant-profile (participant principal))
    (map-get? participant-profiles { participant: participant })
)

(define-read-only (is-participant-consented
        (participant principal)
        (trial-id uint)
    )
    (match (get-participant-consent participant trial-id)
        consent (and (get consent-given consent) (not (get is-withdrawn consent)))
        false
    )
)

(define-read-only (get-trial-status (trial-id uint))
    (match (map-get? trials { trial-id: trial-id })
        trial (let (
                (current-block (get-current-block))
                (is-started (>= current-block (get start-block trial)))
                (is-ended (>= current-block (get end-block trial)))
                (is-expired (match (map-get? trial-expiration-notifications { trial-id: trial-id })
                    notification-data (get expired notification-data)
                    false
                ))
            )
            (some {
                trial-id: trial-id,
                is-active: (get is-active trial),
                is-started: is-started,
                is-ended: is-ended,
                is-expired: is-expired,
                participants: (get current-participants trial),
                max-participants: (get max-participants trial),
                blocks-remaining: (if is-ended
                    u0
                    (- (get end-block trial) current-block)
                ),
            })
        )
        none
    )
)

(define-read-only (get-contract-info)
    {
        owner: (var-get contract-owner),
        next-trial-id: (var-get next-trial-id),
        next-consent-id: (var-get next-consent-id),
        next-credential-id: (var-get next-credential-id),
        current-block: (get-current-block),
    }
)

(define-read-only (calculate-age-at-block
        (birth-block uint)
        (target-block uint)
    )
    (if (>= target-block birth-block)
        (/ (- target-block birth-block) u52560)
        u0
    )
)

(define-read-only (validate-consent-eligibility
        (participant principal)
        (trial-id uint)
    )
    (match (map-get? trials { trial-id: trial-id })
        trial (let (
                (current-block (get-current-block))
                (already-consented (is-some (map-get? participant-trials {
                    participant: participant,
                    trial-id: trial-id,
                })))
                (trial-full (>= (get current-participants trial) (get max-participants trial)))
                (trial-ended (>= current-block (get end-block trial)))
                (trial-not-started (< current-block (get start-block trial)))
            )
            (ok {
                eligible: (and
                    (get is-active trial)
                    (not already-consented)
                    (not trial-full)
                    (not trial-ended)
                    (not trial-not-started)
                ),
                reasons: {
                    trial-active: (get is-active trial),
                    not-already-consented: (not already-consented),
                    trial-not-full: (not trial-full),
                    trial-not-ended: (not trial-ended),
                    trial-started: (not trial-not-started),
                },
            })
        )
        ERR-TRIAL-NOT-FOUND
    )
)

(define-read-only (get-active-trials)
    (ok "Use external indexing to list active trials")
)

(define-read-only (get-participant-trials (participant principal))
    (ok "Use external indexing to list participant trials")
)
(define-map trial-expiration-notifications
    { trial-id: uint }
    { expired: bool }
)

(define-public (expire-trial (trial-id uint))
    (let ((trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND)))
        (if (>= (get-current-block) (get end-block trial))
            (begin
                (map-set trial-expiration-notifications { trial-id: trial-id } { expired: true })
                (map-set trials { trial-id: trial-id }
                    (merge trial { is-active: false })
                )
                (ok true)
            )
            (ok false)
        )
    )
)

(define-read-only (get-trial-expiration-notifications (trial-id uint))
    (map-get? trial-expiration-notifications { trial-id: trial-id })
)

(define-private (calculate-percentage
        (numerator uint)
        (denominator uint)
    )
    (if (is-eq denominator u0)
        u0
        (/ (* numerator u100) denominator)
    )
)

(define-public (update-trial-analytics (trial-id uint))
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id }) ERR-TRIAL-NOT-FOUND))
            (current-block (get-current-block))
            (total-enrolled (get current-participants trial))
            (total-withdrawn u0)
            (total-completed u0)
            (compensation-paid u0)
        )
        (asserts! (is-eq tx-sender (get organizer trial)) ERR-NOT-AUTHORIZED)
        (asserts! (>= current-block (get end-block trial)) ERR-TRIAL-NOT-STARTED)

        (let (
                (completion-rate (calculate-percentage total-completed total-enrolled))
                (withdrawal-rate (calculate-percentage total-withdrawn total-enrolled))
            )
            (map-set trial-analytics { trial-id: trial-id } {
                total-enrolled: total-enrolled,
                total-withdrawn: total-withdrawn,
                total-completed: total-completed,
                completion-rate: completion-rate,
                withdrawal-rate: withdrawal-rate,
                compensation-paid: compensation-paid,
                average-participation-duration: u0,
                last-updated: current-block,
            })
        )
        (ok true)
    )
)

(define-read-only (get-trial-analytics (trial-id uint))
    (map-get? trial-analytics { trial-id: trial-id })
)

(define-read-only (get-trial-performance-summary (trial-id uint))
    (match (map-get? trial-analytics { trial-id: trial-id })
        analytics (some {
            trial-id: trial-id,
            enrolled: (get total-enrolled analytics),
            completed: (get total-completed analytics),
            withdrawn: (get total-withdrawn analytics),
            completion-rate: (get completion-rate analytics),
            withdrawal-rate: (get withdrawal-rate analytics),
            total-compensation: (get compensation-paid analytics),
            last-updated: (get last-updated analytics),
        })
        none
    )
)

(define-read-only (get-participant-credential
        (participant principal)
        (credential-id uint)
    )
    (map-get? participant-credentials {
        participant: participant,
        credential-id: credential-id,
    })
)

(define-read-only (get-trial-credential-requirements (trial-id uint))
    (ok "Use external indexing to list trial credential requirements")
)

(define-read-only (get-credential-verifier (verifier principal))
    (map-get? credential-verifiers { verifier: verifier })
)

(define-read-only (check-participant-credentials
        (participant principal)
        (trial-id uint)
    )
    (let (
            (trial (unwrap! (map-get? trials { trial-id: trial-id })
                (err "trial-not-found")
            ))
            (current-block (get-current-block))
        )
        (ok {
            participant: participant,
            trial-id: trial-id,
            credentials-valid: true,
            checked-at: current-block,
        })
    )
)

(define-read-only (validate-credential-for-trial
        (participant principal)
        (credential-id uint)
        (trial-id uint)
        (credential-type (string-ascii 32))
    )
    (let (
            (credential (unwrap!
                (map-get? participant-credentials {
                    participant: participant,
                    credential-id: credential-id,
                })
                (err "credential-not-found")
            ))
            (requirement (map-get? trial-credential-requirements {
                trial-id: trial-id,
                credential-type: credential-type,
            }))
            (current-block (get-current-block))
        )
        (let (
                (is-verified (is-eq (get verification-status credential) "verified"))
                (is-active (get is-active credential))
                (not-expired (> (get expiration-date credential) current-block))
                (correct-type (is-eq (get credential-type credential) credential-type))
            )
            (ok {
                valid: (and
                    is-verified
                    is-active
                    not-expired
                    correct-type
                ),
                verified: is-verified,
                active: is-active,
                expired: (not not-expired),
                type-match: correct-type,
                verification-status: (get verification-status credential),
            })
        )
    )
)

(define-read-only (get-credential-verification-info)
    {
        next-credential-id: (var-get next-credential-id),
        total-verifiers: u0,
        verification-statuses: (list "pending" "verified" "rejected" "expired"),
    }
)
