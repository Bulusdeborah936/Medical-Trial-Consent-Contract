(define-data-var contract-owner principal tx-sender)
(define-data-var next-trial-id uint u1)
(define-data-var next-consent-id uint u1)
(define-data-var current-block-height uint u1)

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

(define-public (advance-block)
    (begin
        (increment-block)
        (ok (get-current-block))
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
            )
            (some {
                trial-id: trial-id,
                is-active: (get is-active trial),
                is-started: is-started,
                is-ended: is-ended,
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
