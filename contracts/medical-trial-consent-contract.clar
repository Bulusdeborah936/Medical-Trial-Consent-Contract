;; Medical Trial Consent Contract with Smart Notification System
;; Comprehensive contract for managing medical trial participation, consent, and notifications

;; Data variables for core functionality
(define-data-var contract-owner principal tx-sender)
(define-data-var next-trial-id uint u1)
(define-data-var next-consent-id uint u1)
(define-data-var next-credential-id uint u1)
(define-data-var current-block-height uint u1)
(define-data-var total-escrow-balance uint u0)

;; Smart Notification System variables
(define-data-var notification-counter uint u0)

;; Core trial management maps
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

;; Smart Notification System maps
(define-map notifications 
    { notification-id: uint }
    {
        trial-id: uint,
        participant: principal,
        notification-type: (string-ascii 50),
        message: (string-utf8 500),
        created-at: uint,
        delivered: bool,
        read: bool,
        delivery-method: (string-ascii 20)
    }
)

(define-map participant-notification-preferences
    { participant: principal, notification-type: (string-ascii 50) }
    { enabled: bool, delivery-method: (string-ascii 20) }
)

(define-map notification-analytics
    { trial-id: uint }
    {
        total-sent: uint,
        total-delivered: uint,
        total-read: uint,
        last-notification: uint
    }
)

;; Error constants for core functionality
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

;; Error constants for Smart Notification System
(define-constant ERR-NOTIFICATION-NOT-FOUND (err u300))
(define-constant ERR-INVALID-NOTIFICATION-TYPE (err u301))
(define-constant ERR-NOTIFICATION-DISABLED (err u302))
(define-constant ERR-INVALID-DELIVERY-METHOD (err u303))

;; Private helper functions
(define-private (get-current-block)
    (var-get current-block-height)
)

(define-private (increment-block)
    (var-set current-block-height (+ (var-get current-block-height) u1))
)

(define-private (is-valid-notification-type (notification-type (string-ascii 50)))
    (or 
        (is-eq notification-type "trial-start-reminder")
        (is-eq notification-type "trial-end-warning")
        (is-eq notification-type "compensation-available")
        (is-eq notification-type "consent-expiring")
    )
)

(define-private (is-valid-delivery-method (delivery-method (string-ascii 20)))
    (or
        (is-eq delivery-method "email")
        (is-eq delivery-method "sms")
        (is-eq delivery-method "in-app")
    )
)

;; Core trial management functions
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

        ;; Initialize notification analytics for the trial
        (map-set notification-analytics { trial-id: trial-id } {
            total-sent: u0,
            total-delivered: u0,
            total-read: u0,
            last-notification: u0,
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
        
        ;; Set default notification preferences
        (unwrap-panic (set-notification-preference "trial-start-reminder" true "in-app"))
        (unwrap-panic (set-notification-preference "trial-end-warning" true "in-app"))
        (unwrap-panic (set-notification-preference "compensation-available" true "in-app"))
        (unwrap-panic (set-notification-preference "consent-expiring" true "in-app"))
        
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

        ;; Create consent confirmation notification
        (unwrap-panic (create-notification 
            trial-id 
            tx-sender 
            "consent-confirmation" 
            u"Your consent for this medical trial has been successfully recorded."
            "in-app"
        ))

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

        ;; Create withdrawal confirmation notification
        (unwrap-panic (create-notification 
            trial-id 
            tx-sender 
            "consent-withdrawal" 
            u"Your consent withdrawal has been processed successfully."
            "in-app"
        ))

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

        ;; Create compensation claimed notification
        (unwrap-panic (create-notification 
            trial-id 
            tx-sender 
            "compensation-claimed" 
            u"Your trial compensation has been successfully processed."
            "in-app"
        ))

        (ok compensation-amount)
    )
)

(define-public (advance-block)
    (begin
        (increment-block)
        (ok (get-current-block))
    )
)

;; Smart Notification System functions
(define-public (create-notification
        (trial-id uint)
        (participant principal)
        (notification-type (string-ascii 50))
        (message (string-utf8 500))
        (delivery-method (string-ascii 20))
    )
    (let (
            (notification-id (+ (var-get notification-counter) u1))
            (current-block (get-current-block))
            (preference (get-notification-preference participant notification-type))
        )
        (asserts! (is-valid-notification-type notification-type) ERR-INVALID-NOTIFICATION-TYPE)
        (asserts! (is-valid-delivery-method delivery-method) ERR-INVALID-DELIVERY-METHOD)
        (asserts! (is-some (map-get? trials { trial-id: trial-id })) ERR-TRIAL-NOT-FOUND)
        
        ;; Check if participant has notifications enabled for this type
        (asserts! (match preference
            pref (get enabled pref)
            true ;; Default to enabled if no preference set
        ) ERR-NOTIFICATION-DISABLED)

        (map-set notifications { notification-id: notification-id } {
            trial-id: trial-id,
            participant: participant,
            notification-type: notification-type,
            message: message,
            created-at: current-block,
            delivered: false,
            read: false,
            delivery-method: delivery-method
        })

        ;; Update trial analytics
        (match (map-get? notification-analytics { trial-id: trial-id })
            analytics (map-set notification-analytics { trial-id: trial-id }
                (merge analytics { 
                    total-sent: (+ (get total-sent analytics) u1),
                    last-notification: current-block
                })
            )
            (map-set notification-analytics { trial-id: trial-id } {
                total-sent: u1,
                total-delivered: u0,
                total-read: u0,
                last-notification: current-block
            })
        )

        (var-set notification-counter notification-id)
        (ok notification-id)
    )
)

(define-public (mark-notification-delivered (notification-id uint))
    (let (
            (notification (unwrap! (map-get? notifications { notification-id: notification-id })
                ERR-NOTIFICATION-NOT-FOUND))
        )
        (asserts! (not (get delivered notification)) (err u400)) ;; Already delivered

        (map-set notifications { notification-id: notification-id }
            (merge notification { delivered: true })
        )

        ;; Update trial analytics
        (let ((trial-id (get trial-id notification)))
            (match (map-get? notification-analytics { trial-id: trial-id })
                analytics (map-set notification-analytics { trial-id: trial-id }
                    (merge analytics { 
                        total-delivered: (+ (get total-delivered analytics) u1)
                    })
                )
                false
            )
        )

        (ok true)
    )
)

(define-public (mark-notification-read (notification-id uint))
    (let (
            (notification (unwrap! (map-get? notifications { notification-id: notification-id })
                ERR-NOTIFICATION-NOT-FOUND))
        )
        (asserts! (is-eq (get participant notification) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get read notification)) (err u401)) ;; Already read

        (map-set notifications { notification-id: notification-id }
            (merge notification { read: true })
        )

        ;; Update trial analytics
        (let ((trial-id (get trial-id notification)))
            (match (map-get? notification-analytics { trial-id: trial-id })
                analytics (map-set notification-analytics { trial-id: trial-id }
                    (merge analytics { 
                        total-read: (+ (get total-read analytics) u1)
                    })
                )
                false
            )
        )

        (ok true)
    )
)

(define-public (set-notification-preference
        (notification-type (string-ascii 50))
        (enabled bool)
        (delivery-method (string-ascii 20))
    )
    (begin
        (asserts! (is-valid-notification-type notification-type) ERR-INVALID-NOTIFICATION-TYPE)
        (asserts! (is-valid-delivery-method delivery-method) ERR-INVALID-DELIVERY-METHOD)

        (map-set participant-notification-preferences 
            { participant: tx-sender, notification-type: notification-type }
            { enabled: enabled, delivery-method: delivery-method }
        )
        (ok true)
    )
)

;; Read-only functions for core functionality
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

(define-read-only (get-contract-info)
    {
        owner: (var-get contract-owner),
        next-trial-id: (var-get next-trial-id),
        next-consent-id: (var-get next-consent-id),
        notification-counter: (var-get notification-counter),
        current-block: (get-current-block),
    }
)

;; Smart Notification System read-only functions
(define-read-only (get-notification (notification-id uint))
    (map-get? notifications { notification-id: notification-id })
)

(define-read-only (get-notification-preference (participant principal) (notification-type (string-ascii 50)))
    (map-get? participant-notification-preferences 
        { participant: participant, notification-type: notification-type }
    )
)

(define-read-only (get-notification-analytics (trial-id uint))
    (map-get? notification-analytics { trial-id: trial-id })
)

(define-read-only (get-participant-notifications (participant principal) (limit uint))
    (ok "Use external indexing to efficiently query participant notifications")
)

(define-read-only (get-notification-summary)
    {
        total-notifications: (var-get notification-counter),
        supported-types: (list "trial-start-reminder" "trial-end-warning" "compensation-available" "consent-expiring"),
        delivery-methods: (list "email" "sms" "in-app")
    }
)
