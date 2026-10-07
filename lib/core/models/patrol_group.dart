/// Nhóm workflow tuần tra (dùng chung toàn app, kể cả gửi `.name` lên API).
enum PatrolGroup { Patrol, Audit, QualityPatrol, AssetUpdate, FixedAsset }

enum PatrolAction { before, after, recheck, summary }
