;; Bottleneck Identification System
;; Identifies and prioritizes process bottlenecks

(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-DATA (err u301))
(define-constant ERR-NOT-FOUND (err u302))
(define-constant ERR-ALREADY-RESOLVED (err u303))

;; Bottleneck severity levels
(define-constant SEVERITY-LOW u1)
(define-constant SEVERITY-MEDIUM u2)
(define-constant SEVERITY-HIGH u3)
(define-constant SEVERITY-CRITICAL u4)

;; Data structures
(define-map bottlenecks
  { process-id: (string-ascii 50), bottleneck-id: uint }
  {
    description: (string-ascii 200),
    severity: uint,
    impact-score: uint,
    frequency: uint,
    identified-by: principal,
    identification-block: uint,
    status: uint,
    resolution-deadline: uint
  }
)

(define-map bottleneck-analysis
  { process-id: (string-ascii 50) }
  {
    total-bottlenecks: uint,
    critical-count: uint,
    high-count: uint,
    medium-count: uint,
    low-count: uint,
    last-analysis: uint
  }
)

(define-map resolution-recommendations
  { bottleneck-id: uint }
  {
    recommendation: (string-ascii 300),
    estimated-effort: uint,
    expected-improvement: uint,
    priority-score: uint,
    recommended-by: principal
  }
)

(define-data-var bottleneck-counter uint u0)

;; Status constants
(define-constant STATUS-IDENTIFIED u0)
(define-constant STATUS-ANALYZING u1)
(define-constant STATUS-RESOLVING u2)
(define-constant STATUS-RESOLVED u3)

;; Public functions

;; Identify a new bottleneck
(define-public (identify-bottleneck
  (process-id (string-ascii 50))
  (description (string-ascii 200))
  (impact-score uint)
  (frequency uint))
  (let (
    (identifier tx-sender)
    (bottleneck-id (+ (var-get bottleneck-counter) u1))
    (severity (calculate-severity impact-score frequency))
    (deadline (+ block-height u1000)) ;; 1000 blocks deadline
  )
    (asserts! (> impact-score u0) ERR-INVALID-DATA)
    (asserts! (> frequency u0) ERR-INVALID-DATA)
    (asserts! (<= impact-score u100) ERR-INVALID-DATA)

    (var-set bottleneck-counter bottleneck-id)

    (map-set bottlenecks
      { process-id: process-id, bottleneck-id: bottleneck-id }
      {
        description: description,
        severity: severity,
        impact-score: impact-score,
        frequency: frequency,
        identified-by: identifier,
        identification-block: block-height,
        status: STATUS-IDENTIFIED,
        resolution-deadline: deadline
      }
    )

    ;; Update analysis data
    (update-bottleneck-analysis process-id severity)

    (ok bottleneck-id)
  )
)

;; Add resolution recommendation
(define-public (add-recommendation
  (bottleneck-id uint)
  (recommendation (string-ascii 300))
  (estimated-effort uint)
  (expected-improvement uint))
  (let (
    (recommender tx-sender)
    (priority-score (calculate-priority-score estimated-effort expected-improvement))
  )
    (asserts! (> estimated-effort u0) ERR-INVALID-DATA)
    (asserts! (> expected-improvement u0) ERR-INVALID-DATA)

    (map-set resolution-recommendations
      { bottleneck-id: bottleneck-id }
      {
        recommendation: recommendation,
        estimated-effort: estimated-effort,
        expected-improvement: expected-improvement,
        priority-score: priority-score,
        recommended-by: recommender
      }
    )
    (ok true)
  )
)

;; Update bottleneck status
(define-public (update-bottleneck-status (process-id (string-ascii 50)) (bottleneck-id uint) (new-status uint))
  (let ((bottleneck-data (unwrap! (map-get? bottlenecks { process-id: process-id, bottleneck-id: bottleneck-id }) ERR-NOT-FOUND)))
    (asserts! (<= new-status STATUS-RESOLVED) ERR-INVALID-DATA)

    (map-set bottlenecks
      { process-id: process-id, bottleneck-id: bottleneck-id }
      (merge bottleneck-data { status: new-status })
    )
    (ok true)
  )
)

;; Analyze process bottlenecks
(define-public (analyze-process-bottlenecks (process-id (string-ascii 50)))
  (let ((analysis-data (get-or-create-analysis process-id)))
    ;; Perform bottleneck analysis logic here
    (map-set bottleneck-analysis
      { process-id: process-id }
      (merge analysis-data { last-analysis: block-height })
    )
    (ok true)
  )
)

;; Private functions

(define-private (calculate-severity (impact-score uint) (frequency uint))
  (let ((combined-score (+ impact-score frequency)))
    (if (>= combined-score u150)
      SEVERITY-CRITICAL
      (if (>= combined-score u100)
        SEVERITY-HIGH
        (if (>= combined-score u50)
          SEVERITY-MEDIUM
          SEVERITY-LOW
        )
      )
    )
  )
)

(define-private (calculate-priority-score (effort uint) (improvement uint))
  (if (> effort u0)
    (/ (* improvement u100) effort)
    u0
  )
)

(define-private (update-bottleneck-analysis (process-id (string-ascii 50)) (severity uint))
  (let ((current-analysis (get-or-create-analysis process-id)))
    (map-set bottleneck-analysis
      { process-id: process-id }
      (merge current-analysis {
        total-bottlenecks: (+ (get total-bottlenecks current-analysis) u1),
        critical-count: (if (is-eq severity SEVERITY-CRITICAL)
                         (+ (get critical-count current-analysis) u1)
                         (get critical-count current-analysis)),
        high-count: (if (is-eq severity SEVERITY-HIGH)
                     (+ (get high-count current-analysis) u1)
                     (get high-count current-analysis)),
        medium-count: (if (is-eq severity SEVERITY-MEDIUM)
                       (+ (get medium-count current-analysis) u1)
                       (get medium-count current-analysis)),
        low-count: (if (is-eq severity SEVERITY-LOW)
                    (+ (get low-count current-analysis) u1)
                    (get low-count current-analysis))
      })
    )
  )
)

(define-private (get-or-create-analysis (process-id (string-ascii 50)))
  (match (map-get? bottleneck-analysis { process-id: process-id })
    existing-analysis existing-analysis
    {
      total-bottlenecks: u0,
      critical-count: u0,
      high-count: u0,
      medium-count: u0,
      low-count: u0,
      last-analysis: u0
    }
  )
)

;; Read-only functions

(define-read-only (get-bottleneck (process-id (string-ascii 50)) (bottleneck-id uint))
  (map-get? bottlenecks { process-id: process-id, bottleneck-id: bottleneck-id })
)

(define-read-only (get-process-analysis (process-id (string-ascii 50)))
  (map-get? bottleneck-analysis { process-id: process-id })
)

(define-read-only (get-recommendation (bottleneck-id uint))
  (map-get? resolution-recommendations { bottleneck-id: bottleneck-id })
)

(define-read-only (get-bottleneck-count)
  (var-get bottleneck-counter)
)

(define-read-only (get-critical-bottlenecks (process-id (string-ascii 50)))
  (match (map-get? bottleneck-analysis { process-id: process-id })
    analysis-data (some (get critical-count analysis-data))
    none
  )
)
