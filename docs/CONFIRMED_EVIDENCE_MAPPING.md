# الربط المعتمد لصور الأدلة

هذا الجدول يحل محل الربط التصويري السابق. لا توجد بدائل بين صور الأدلة؛ الملفات الناقصة تُعرض معها رسالة واضحة. عند إضافة ملف ناقص بالاسم المحدد يُحمّل تلقائيًا دون تغيير الربط.

| الدليل | ملف الصورة داخل assets/evidence | الحالة |
| --- | --- | --- |
| سجل قفل مكتب آدم | `evidence_1_lock_log.png` | غير موجود حاليًا |
| موضع تمثال الميزان الفارغ | `evidence_2_empty_statue_spot.png` | غير موجود حاليًا |
| سجل اتصالات رقم آدم | `evidence_2_phone.png` | مرتبط ومحمّل |
| مسودة نقل المسؤولية | `evidence_3_financial_file.png` | مرتبط ومحمّل |
| تسجيل مكالمة ليلى | `evidence_5_call_recording.png` | غير موجود حاليًا |
| مقطع أرشيفي بصوت آدم | `evidence_6_voice_archive.png` | غير موجود حاليًا |
| محضر الدخول وتفتيش الحقائب | `evidence_7_bag_inspection.png` | مرتبط ومحمّل |
| التمثال في خزانة الاستقبال | `evidence_1_statue.png` | مرتبط ومحمّل |
| صورة أرشيفية لتمثال الميزان | `evidence_5_office_photo.png` | مرتبط ومحمّل |
| سجل فتح خزانة الاستقبال | `evidence_10_cabinet_log.png` | مرتبط ومحمّل |
| عينات الألياف والحقيبة | `evidence_6_fibers.png` | مرتبط ومحمّل |
| سجلات الخوادم والكاميرات | `evidence_12_server_camera_logs.png` | مرتبط ومحمّل |
| رسائل تهديد مازن | `evidence_7_threat_note.png` | مرتبط ومحمّل |
| ملف شكوى شقيق ليلى | `evidence_14_brother_complaint.png` | مرتبط ومحمّل |
| دفتر التحويلات واعتمادات آدم | `evidence_15_transfer_ledger.png` | مرتبط ومحمّل |

التقرير الجنائي يبقى مرتبطًا بملفه evidence_9_forensic_report.png كسجل تقرير منفصل، وليس بديلًا لأحد الأدلة الخمسة عشر. أزيل ربط صورة بطاقة الدخول بسجل القفل، وصورة الهاتف بالتسجيل والأرشيف، وصورة المراقبة بالسجلات، والملف المالي بشكوى الشقيق أو دفتر التحويلات. أزيلت شروط العرض والبدائل القديمة الخاصة بتلك الاستعارات، لأن كل دليل بات له المسار المعتمد الخاص به.

اختبار test_confirmed_evidence_mapping.gd اجتاز 79 تحققًا في تشغيل رسومي على 1280×720: المسارات المطابقة حرفيًا، والملفات الناقصة دون بدائل، والمعاينة قبل الجمع، وبقاء الدفتر خاليًا قبل الجمع، وإتاحة الأدلة الخمسة عشر، وعرض الصورة الصحيحة في الفحص وتفاصيل الدفتر. جميع الملفات الإحدى عشرة الموجودة حُمّلت بنجاح.


## Supplied assets update
All fifteen assigned evidence PNG files are now present, including lock log, empty statue spot, call recording and voice archive. Exact mappings are unchanged; no substitutions. Opening uses `Moody Detective’s Nighttime Study.png`, switching to `Noir Detective Office_ Incoming Call.png` after answering Yazan (including restored call state). Crime-scene backgrounds stay unchanged.
