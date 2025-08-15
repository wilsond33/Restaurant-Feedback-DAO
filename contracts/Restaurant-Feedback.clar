;; title: Restaurant-Feedback
;; version:
;; summary:
;; description:



(define-non-fungible-token diner-pass uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-VOTING-ENDED (err u104))
(define-constant ERR-INVALID-PROPOSAL (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))

(define-data-var token-id-nonce uint u1)
(define-data-var proposal-id-nonce uint u1)
(define-data-var restaurant-name (string-ascii 64) "The Blockchain Bistro")

(define-map proposals
    uint
    {
        title: (string-ascii 128),
        description: (string-ascii 512),
        proposer: principal,
        yes-votes: uint,
        no-votes: uint,
        end-block: uint,
        executed: bool,
        proposal-type: (string-ascii 32)
    }
)

(define-map votes
    { proposal-id: uint, voter: principal }
    { vote: bool, voting-power: uint }
)

(define-map member-stats
    principal
    {
        total-votes: uint,
        successful-proposals: uint,
        reputation-score: uint,
        last-activity: uint
    }
)

(define-map perks-claimed
    { member: principal, perk-type: (string-ascii 32) }
    { claimed: bool, claim-block: uint }
)

(define-read-only (get-last-token-id)
    (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? diner-pass token-id))
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-member-stats (member principal))
    (default-to
        { total-votes: u0, successful-proposals: u0, reputation-score: u0, last-activity: u0 }
        (map-get? member-stats member)
    )
)

(define-read-only (get-voting-power (member principal))
    (let ((stats (get-member-stats member)))
        (+ u1 (/ (get reputation-score stats) u10))
    )
)

(define-read-only (is-eligible-for-perk (member principal) (perk-type (string-ascii 32)))
    (let ((stats (get-member-stats member)))
        (and
            (>= (get reputation-score stats) u50)
            (>= (get total-votes stats) u5)
            (is-none (map-get? perks-claimed { member: member, perk-type: perk-type }))
        )
    )
)

(define-read-only (get-restaurant-name)
    (var-get restaurant-name)
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
        (nft-transfer? diner-pass token-id sender recipient)
    )
)

(define-public (mint-diner-pass (recipient principal))
    (let ((token-id (var-get token-id-nonce)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (try! (nft-mint? diner-pass token-id recipient))
        (var-set token-id-nonce (+ token-id u1))
        (ok token-id)
    )
)

(define-public (create-proposal
    (title (string-ascii 128))
    (description (string-ascii 512))
    (proposal-type (string-ascii 32))
    (voting-period uint)
)
    (let 
        (
            (proposal-id (var-get proposal-id-nonce))
            (end-block (+ stacks-block-height voting-period))
        )
        (asserts! (> (len title) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> (len description) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> voting-period u0) ERR-INVALID-PROPOSAL)
        (asserts! (is-some (nft-get-owner? diner-pass u1)) (err u107))
        
        (map-set proposals proposal-id
            {
                title: title,
                description: description,
                proposer: tx-sender,
                yes-votes: u0,
                no-votes: u0,
                end-block: end-block,
                executed: false,
                proposal-type: proposal-type
            }
        )
        
        (var-set proposal-id-nonce (+ proposal-id u1))
        (update-member-activity tx-sender)
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (support bool))
    (let 
        (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (voting-power (get-voting-power tx-sender))
            (current-block stacks-block-height)
        )
        (asserts! (<= current-block (get end-block proposal)) ERR-VOTING-ENDED)
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
        (asserts! (is-some (nft-get-owner? diner-pass u1)) (err u107))
        
        (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { vote: support, voting-power: voting-power }
        )
        
        (if support
            (map-set proposals proposal-id
                (merge proposal { yes-votes: (+ (get yes-votes proposal) voting-power) })
            )
            (map-set proposals proposal-id
                (merge proposal { no-votes: (+ (get no-votes proposal) voting-power) })
            )
        )
        
        (update-member-voting-stats tx-sender)
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (>= stacks-block-height (get end-block proposal)) ERR-VOTING-ENDED)
        (asserts! (not (get executed proposal)) (err u108))
        (asserts! (> (get yes-votes proposal) (get no-votes proposal)) (err u109))
        
        (map-set proposals proposal-id
            (merge proposal { executed: true })
        )
        
        (update-proposer-success (get proposer proposal))
        (ok true)
    )
)

(define-public (claim-perk (perk-type (string-ascii 32)))
    (let ((current-block stacks-block-height))
        (asserts! (is-eligible-for-perk tx-sender perk-type) (err u110))
        
        (map-set perks-claimed
            { member: tx-sender, perk-type: perk-type }
            { claimed: true, claim-block: current-block }
        )
        
        (ok true)
    )
)

(define-public (update-restaurant-name (new-name (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set restaurant-name new-name)
        (ok true)
    )
)

(define-private (update-member-activity (member principal))
    (let 
        (
            (current-stats (get-member-stats member))
            (current-block stacks-block-height)
        )
        (map-set member-stats member
            (merge current-stats { last-activity: current-block })
        )
    )
)

(define-private (update-member-voting-stats (member principal))
    (let ((current-stats (get-member-stats member)))
        (map-set member-stats member
            (merge current-stats 
                { 
                    total-votes: (+ (get total-votes current-stats) u1),
                    reputation-score: (+ (get reputation-score current-stats) u5),
                    last-activity: stacks-block-height
                }
            )
        )
    )
)

(define-private (update-proposer-success (proposer principal))
    (let ((current-stats (get-member-stats proposer)))
        (map-set member-stats proposer
            (merge current-stats 
                { 
                    successful-proposals: (+ (get successful-proposals current-stats) u1),
                    reputation-score: (+ (get reputation-score current-stats) u20)
                }
            )
        )
    )
)

(define-public (batch-mint-passes (recipients (list 50 principal)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (ok (map mint-single-pass recipients))
    )
)

(define-private (mint-single-pass (recipient principal))
    (let ((token-id (var-get token-id-nonce)))
        (match (nft-mint? diner-pass token-id recipient)
            success (begin
                (var-set token-id-nonce (+ token-id u1))
                token-id
            )
            error u0
        )
    )
)

(define-read-only (get-proposal-results (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (ok {
            title: (get title proposal),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            total-votes: (+ (get yes-votes proposal) (get no-votes proposal)),
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            executed: (get executed proposal)
        })
        ERR-PROPOSAL-NOT-FOUND
    )
)

(define-read-only (get-active-proposals)
    (ok "Use off-chain indexing to get active proposals")
)

(define-read-only (get-member-perks (member principal))
    (let ((stats (get-member-stats member)))
        (ok {
            reputation-score: (get reputation-score stats),
            total-votes: (get total-votes stats),
            successful-proposals: (get successful-proposals stats),
            voting-power: (get-voting-power member)
        })
    )
)
