# WhatsApp Customer Support Workflow (AI + )

## 1. الهدف من الـ Workflow
بناء نظام خدمة عملاء ذكي عبر **WhatsApp** باستخدام ** + ChatGPT** يقوم بـ:
- فهم سبب تواصل العميل
- تصنيف الطلب بدقة
- تنفيذ القرار الصحيح (سعر – ضمان – شكوى – طلب)
- الرد بشكل واضح أو التحويل لموظف عند الحاجة

---

## 2. القناة
- **Channel:** WhatsApp (Cloud API / Twilio)
- **Entry Point:** Webhook ()

---

## 3. تعريف الكيانات الأساسية

### 3.1 العميل
- نوع العميل:
  - فرد
  - شركة
- الاسم (اختياري)
- رقم الهاتف (Primary ID)
- اللغة: عربي / إنجليزي

---

## 4. التصنيف الرئيسي (Intent)

```
سبب التواصل
├─ استفسار
├─ شكوى
├─ طلب
├─ متابعة
└─ دردشة / عام (Chit-chat)
```

يتم استخراجه باستخدام ChatGPT (Intent Classifier فقط).

---

## 5. الاستفسارات (Inquiry Flow)

### 5.1 أسعار
- انواع منتجات
  -منتجات مراتب
    [
    # Spring Air
    {"brand": "Spring Air", "model": "يورو", "height_cm": 42},
    {"brand": "Spring Air", "model": "جوفالي", "height_cm": 34},
    {"brand": "Spring Air", "model": "نوبيليتى", "height_cm": 36},
    {"brand": "Spring Air", "model": "شيرى", "height_cm": 26},
    {"brand": "Spring Air", "model": "إيكوس", "height_cm": 25},
    {"brand": "Spring Air", "model": "روتانا", "height_cm": 25},
    {"brand": "Spring Air", "model": "لاتكس زون", "height_cm": 18},
    {"brand": "Spring Air", "model": "جوبى", "height_cm": 27},
    {"brand": "Spring Air", "model": "هيلو", "height_cm": 23},
    {"brand": "Spring Air", "model": "روز مارى بيلوتوب", "height_cm": 28},
    {"brand": "Spring Air", "model": "روز مارى", "height_cm": 25},
    {"brand": "Spring Air", "model": "بيلندا", "height_cm": 30},
    {"brand": "Spring Air", "model": "ماكنزى", "height_cm": 25},

    # Janssen Pristeg
    {"brand": "Janssen Pristeg", "model": "يانسن بيدك", "height_cm": 25},
    {"brand": "Janssen Pristeg", "model": "جوري", "height_cm": 27},
    {"brand": "Janssen Pristeg", "model": "كازاك", "height_cm": 27},
    {"brand": "Janssen Pristeg", "model": "رويالتى", "height_cm": 35},
    {"brand": "Janssen Pristeg", "model": "ميدي بيدك", "height_cm": 28},
    {"brand": "Janssen Pristeg", "model": "بوكيت قطن", "height_cm": 30},
    {"brand": "Janssen Pristeg", "model": "بوكيت قطن", "height_cm": 27},
    {"brand": "Janssen Pristeg", "model": "اسكاندى", "height_cm": 25},
    {"brand": "Janssen Pristeg", "model": "بلوماس", "height_cm": 20},
    {"brand": "Janssen Pristeg", "model": "توت", "height_cm": 25},
    {"brand": "Janssen Pristeg", "model": "كليوبترا", "height_cm": 24},

    # Bed Janssen
    {"brand": "Bed Janssen", "model": "ماريوت بالقطن", "height_cm": 22},
    {"brand": "Bed Janssen", "model": "ماريوت بالقطن", "height_cm": 17},
    {"brand": "Bed Janssen", "model": "ماريوت", "height_cm": 22},
    {"brand": "Bed Janssen", "model": "ماريوت", "height_cm": 17},
    {"brand": "Bed Janssen", "model": "كتراكت بيلوتوب", "height_cm": 29},
    {"brand": "Bed Janssen", "model": "كتراكت", "height_cm": 31},
    {"brand": "Bed Janssen", "model": "كتراكت", "height_cm": 27},
    {"brand": "Bed Janssen", "model": "المانى قطن", "height_cm": 25},
    {"brand": "Bed Janssen", "model": "سويت دريمز (صيفى/شتوى)", "height_cm": 24},
    {"brand": "Bed Janssen", "model": "اكسترا جولد", "height_cm": 24},

    # Englander
    {"brand": "Englander", "model": "بريليانت", "height_cm": 38},
    {"brand": "Englander", "model": "لولا", "height_cm": 34},
    {"brand": "Englander", "model": "اميريكان سبيريت", "height_cm": 34},
    {"brand": "Englander", "model": "سيتي انجلندر", "height_cm": 25},
    {"brand": "Englander", "model": "سيتي انجلندر", "height_cm": 20},
    {"brand": "Englander", "model": "سيتي انجلندر", "height_cm": 15},
    {"brand": "Englander", "model": "هنى مون", "height_cm": 27},
    {"brand": "Englander", "model": "فيسكوبيدك", "height_cm": 27},
    {"brand": "Englander", "model": "دريمز", "height_cm": 26},
    {"brand": "Englander", "model": "فيكتوريا", "height_cm": 25},
    {"brand": "Englander", "model": "مارفي", "height_cm": 20},
    {"brand": "Englander", "model": "كارس بيلوتوب", "height_cm": 29},
    {"brand": "Englander", "model": "كارس", "height_cm": 27},
    {"brand": "Englander", "model": "ليدى", "height_cm": 25},
    {"brand": "Englander", "model": "سيزونال اكسترا", "height_cm": 30},
    {"brand": "Englander", "model": "سيزونال", "height_cm": 25},
    {"brand": "Englander", "model": "سوبر كلاسيك", "height_cm": 28},
    {"brand": "Englander", "model": "كلاسيك", "height_cm": 24},
    ]

  -منتجات مفروشات
    [
    {"brand": "Janssen&Englander", "type": "خدادية", "model": "ميموري فوم استندر"},
    {"brand": "Janssen&Englander", "type": "خدادية", "model": "ميموري فوم كونتور"},
    {"brand": "Janssen&Englander", "type": "خدادية", "model": "ميموري جيل"},
    {"brand": "Janssen&Englander", "type": "خدادية", "model": "فايبر (اوشن)"},
    {"brand": "Janssen&Englander", "type": "خدادية", "model": "مايكرو فايبر (هيڤن)"},
    {"brand": "Janssen&Englander", "type": "مخدة", "model": "فايبر"},
    {"brand": "Janssen&Englander", "type": "مخدة", "model": "مايكرو فايبر"},
    {"brand": "Janssen&Englander", "type": "ميلتون", "model": "فايبر (اربع اساتك من الجوانب)"},
    {"brand": "Janssen&Englander", "type": "ميلتون", "model": "بشكير"},
    {"brand": "Janssen&Englander", "type": "لحاف", "model": "فايبر"},
    {"brand": "Janssen&Englander", "type": "لحاف", "model": "ميكرو فايبر"},
    {"brand": "Janssen&Englander", "type": "مرتبة تطرية", "model": "فايبر 800جم/م²", "height_cm": 5},
    {"brand": "Janssen&Englander", "type": "مرتبة تطرية", "model": "مايكروفايبر 800جم/م²", "height_cm": 5},
    {"brand": "Janssen&Englander", "type": "مرتبة تطرية", "model": "ميموري فوم", "height_cm": 5},
    ]
- سعر منتج
- مقارنة منتجات
- عروض وخصومات

**مصدر البيانات:** Database (Excel/CSV محوّل إلى SQL)

---

### 5.2 ضمان
- مدة الضمان
- شروط الضمان
- ما لا يشمله الضمان

**مصدر البيانات:** PDF → Vector Database

---

### 5.3 وكلاء
- طلب مشاركة الموقع (Location Pin) أو اسم المدينة/المنطقة
- تحديد أقرب وكيل بناءً على الموقع
- بيانات التواصل
- مواعيد العمل

---

### 5.4 منتجات
- مواصفات
- مقاسات
- توفر المنتج

---

## 6. الشكاوى (Complaint Flow)

**ملاحظة عامة:** في حالة الشكاوى المتعلقة بعيوب في المنتج أو التوصيل، يطلب النظام من العميل رفع **صور/فيديو** لتوضيح المشكلة.

### أنواع الشكاوى

#### 6.1 توصيل
- تأخير
- تلف المنتج
- خطأ في الطلب

#### 6.2 منتج
-هبوط بالمرتبه
-غير مطابق للمواصفات
-تغيير القماش
-مشكلة بالقماش
-تغيير المقاس برغبة العميل
-مشكلة بالسوست
-إضافة مكونات
-تغيير مكونات
-خطأ بالمقاس من المصنع
-خطأ بالمقاس من الوكيل
-حشرة فراش
-رائحة كريهة
-طلب تعديل شامل
-طلب صيانة خارج الضمان
-طلب معاينة
-شكوى
-متابعة طلب تغيير
-ارتجاع
-مشكلة بالشاسيه

#### 6.3 خدمة
- تعامل مندوب
- خدمة ما بعد البيع

---

## 7. الطلبات (Request Flow)

### 7.1 طلب شراء
- اسم المرتبة / المنتج
- مقاس المرتبة
- الكمية
- عنوان التوصيل بالتفصيل
- رقم تواصل إضافي
- ملاحظات التوصيل
- وسيلة الدفع

---

### 7.2 طلب صيانة
- صورة الفاتورة / الضمان (للتحقق من سريان الضمان)
- صورة / فيديو يوضح المشكلة
- تفاصيل المشكلة:
  -هبوط بالمرتبه
  -تغيير القماش
  -مشكلة بالقماش
  -مشكلة بالسوست
  -إضافة مكونات
  -تغيير مكونات
  -حشرة فراش
  -رائحة كريهة
  -طلب تعديل شامل
  -طلب معاينة
  -متابعة طلب تغيير
  -مشكلة بالشاسيه

---

### 7.3 طلب استرجاع
- خلال 14 يوم
- صورة للمنتج (للتحقق من حالة التغليف)
- صورة الفاتورة
- سبب الاسترجاع

---

### 7.4 طلب وكيل
- المدينة
- نوع الشراكة
- بيانات التواصل

---

## 8. المتابعة (Follow-up Flow)

- متابعة طلب شراء
- متابعة طلب صيانة
- متابعة شكوى
- متابعة تقرير
- متابعة تسليم

**متطلبات المتابعة:**
- رقم الطلب / الشكوى

---

## 9. حالات الطلب (Status Lifecycle)

```
New
In Progress
Waiting Customer
Resolved
Escalated
Closed
```

---

## 10. منطق التصعيد (Escalation Rules)

يتم التصعيد تلقائيًا إذا:
- شكوى High Severity
- طلب خارج الصلاحيات
- عدم رد العميل خلال X ساعات
- طلب يدوي من العميل

---

## 11. دور ChatGPT في النظام

### ChatGPT مسؤول عن:
- فهم الرسالة
- إدارة سياق المحادثة (Context Retention) وتذكر تفاصيل المنتج السابق
- تصنيف النية (Intent)
- استخراج البيانات
- صياغة رد واضح

### ChatGPT غير مسؤول عن:
- اتخاذ قرارات تجارية
- حساب أسعار
- الموافقة على استرجاع

---

## 12. نموذج JSON ناتج من ChatGPT

```json
{
  "intent": "complaint",
  "category": "delivery",
  "details": {
    "issue": "delay"
  },
  "confidence": 0.92
}
```

---

## 13. الرد النهائي للعميل

خصائص الرد:
- مختصر
- واضح
- بلغة العميل
- مناسب لـ WhatsApp

---

## 14. Human Handoff
 
 يتم التحويل لموظف في الحالات التالية:
- Intent = human
- Escalated = true
- Confidence < 0.6
- **شرط إضافي:** التحقق من ساعات العمل (Working Hours).
  - داخل ساعات العمل: تحويل مباشر.
  - خارج ساعات العمل: تسجيل تذكرة وإبلاغ العميل بموعد الرد.

---

## 15. Logging & Monitoring

- تسجيل كل محادثة
- تسجيل القرار
- تسجيل وقت الاستجابة

---

## 16. النتيجة النهائية

Workflow قابل للتوسعة، آمن، ويصلح للاستخدام الحقيقي مع آلاف العملاء عبر WhatsApp.
