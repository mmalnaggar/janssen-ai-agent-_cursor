-- Janssen AI - Seed Data
-- Run after schema.sql to populate initial data
-- ============================================

-- ============================================
-- PRODUCTS
-- ============================================
INSERT INTO products (product_code, name_en, name_ar, description_en, description_ar, category, material, firmness_level, support_type, dimensions, warranty_years, is_active)
VALUES
  ('JAN-ORTHO-120', 'Janssen Orthopedic 120cm', 'يانسن أورثوبيديك 120سم', 'Medical-grade orthopedic mattress with firm support for back and spine health.', 'مرتبة طبية أورثوبيديك بدعم متين للظهر والعمود الفقري.', 'orthopedic', 'high-density foam + springs', 'firm', 'orthopedic back support', '120x200 cm', 10, true),
  ('JAN-ORTHO-140', 'Janssen Orthopedic 140cm', 'يانسن أورثوبيديك 140سم', 'Medical-grade orthopedic mattress with firm support for back and spine health.', 'مرتبة طبية أورثوبيديك بدعم متين للظهر والعمود الفقري.', 'orthopedic', 'high-density foam + springs', 'firm', 'orthopedic back support', '140x200 cm', 10, true),
  ('JAN-ORTHO-160', 'Janssen Orthopedic 160cm', 'يانسن أورثوبيديك 160سم', 'Medical-grade orthopedic mattress with firm support for back and spine health.', 'مرتبة طبية أورثوبيديك بدعم متين للظهر والعمود الفقري.', 'orthopedic', 'high-density foam + springs', 'firm', 'orthopedic back support', '160x200 cm', 10, true),
  ('JAN-MEM-120', 'Janssen Memory Foam 120cm', 'يانسن ميموري فوم 120سم', 'Premium memory foam mattress for ultimate comfort and pressure relief.', 'مرتبة ميموري فوم فاخرة لراحة فائقة وتخفيف الضغط.', 'memory_foam', 'memory foam + latex', 'medium', 'pressure relief', '120x200 cm', 12, true),
  ('JAN-MEM-140', 'Janssen Memory Foam 140cm', 'يانسن ميموري فوم 140سم', 'Premium memory foam mattress for ultimate comfort and pressure relief.', 'مرتبة ميموري فوم فاخرة لراحة فائقة وتخفيف الضغط.', 'memory_foam', 'memory foam + latex', 'medium', 'pressure relief', '140x200 cm', 12, true),
  ('JAN-MEM-160', 'Janssen Memory Foam 160cm', 'يانسن ميموري فوم 160سم', 'Premium memory foam mattress for ultimate comfort and pressure relief.', 'مرتبة ميموري فوم فاخرة لراحة فائقة وتخفيف الضغط.', 'memory_foam', 'memory foam + latex', 'medium', 'pressure relief', '160x200 cm', 12, true),
  ('JAN-SOFT-120', 'Janssen Super Soft 120cm', 'يانسن سوبر سوفت 120سم', 'Exceptionally soft mattress for a cloud-like sleeping experience.', 'مرتبة ناعمة استثنائية لتجربة نوم كالسحاب.', 'soft', 'premium soft foam', 'soft', 'comfort', '120x200 cm', 8, true),
  ('JAN-SOFT-140', 'Janssen Super Soft 140cm', 'يانسن سوبر سوفت 140سم', 'Exceptionally soft mattress for a cloud-like sleeping experience.', 'مرتبة ناعمة استثنائية لتجربة نوم كالسحاب.', 'soft', 'premium soft foam', 'soft', 'comfort', '140x200 cm', 8, true),
  ('JAN-SOFT-160', 'Janssen Super Soft 160cm', 'يانسن سوبر سوفت 160سم', 'Exceptionally soft mattress for a cloud-like sleeping experience.', 'مرتبة ناعمة استثنائية لتجربة نوم كالسحاب.', 'soft', 'premium soft foam', 'soft', 'comfort', '160x200 cm', 8, true),
  ('JAN-PILLOW-01', 'Janssen Comfort Pillow', 'وسادة يانسن المريحة', 'Ergonomic memory foam pillow for neck support.', 'وسادة ميموري فوم مريحة لدعم الرقبة.', 'accessories', 'memory foam', NULL, 'neck support', '50x70 cm', 2, true)
ON CONFLICT (product_code) DO NOTHING;

-- ============================================
-- PRICES
-- ============================================
INSERT INTO prices (product_id, price_egp, discount_percent, is_current, valid_from)
VALUES
  ((SELECT id FROM products WHERE product_code = 'JAN-ORTHO-120'), 8500.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-ORTHO-140'), 10500.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-ORTHO-160'), 12500.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-MEM-120'), 11000.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-MEM-140'), 13000.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-MEM-160'), 15000.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-SOFT-120'), 7000.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-SOFT-140'), 8500.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-SOFT-160'), 10000.00, 0, true, CURRENT_DATE),
  ((SELECT id FROM products WHERE product_code = 'JAN-PILLOW-01'), 850.00, 0, true, CURRENT_DATE);

-- ============================================
-- DELIVERY RULES
-- ============================================
INSERT INTO delivery_rules (region, governorate, delivery_days_min, delivery_days_max, delivery_fee_egp, free_delivery_threshold, notes_en, notes_ar, is_active)
VALUES
  ('Cairo', 'القاهرة', 1, 3, 100.00, 5000.00, 'Free delivery above 5,000 EGP', 'توصيل مجاني للطلبات فوق 5,000 جنيه', true),
  ('Giza', 'الجيزة', 1, 3, 100.00, 5000.00, 'Free delivery above 5,000 EGP', 'توصيل مجاني للطلبات فوق 5,000 جنيه', true),
  ('Alexandria', 'الإسكندرية', 3, 5, 200.00, 8000.00, 'Free delivery above 8,000 EGP', 'توصيل مجاني للطلبات فوق 8,000 جنيه', true),
  ('Delta', 'الدلتا', 3, 7, 250.00, 10000.00, 'Covers Tanta, Mansoura, Zagazig', 'يشمل طنطا والمنصورة والزقازيق', true),
  ('Upper Egypt', 'الصعيد', 5, 10, 350.00, 12000.00, 'Covers Assiut, Luxor, Aswan', 'يشمل أسيوط والأقصر وأسوان', true),
  ('Canal Cities', 'مدن القناة', 3, 5, 200.00, 8000.00, 'Covers Suez, Ismailia, Port Said', 'يشمل السويس والإسماعيلية وبورسعيد', true);
