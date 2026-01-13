import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/user_session.dart';

class CreateTicketScreen extends StatefulWidget {
  final String baseUrl;
  final UserSession userSession;

  const CreateTicketScreen({super.key, required this.baseUrl, required this.userSession});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String problemType = '';
  String description = '';
  String customerName = '';
  String billNumber = '';
  DateTime billDate = DateTime.now();
  int? warehouseId;

  List<Map<String, dynamic>> warehouses = [];
  List<PlatformFile> attachedFiles = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchWarehouses();
  }

  Future<void> fetchWarehouses() async {
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/mobile/warehouses?userId=${widget.userSession.id}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          warehouses = data.map((e) => {
            'Id': e['id'] ?? e['Id'],
            'Name': e['name'] ?? e['Name']
          }).toList();
          if (warehouses.isNotEmpty) {
            warehouseId = warehouses[0]['Id'];
          }
        });
      }
    } catch (e) {
      print('Error fetching warehouses: $e');
    }
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        attachedFiles.addAll(result.files);
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() => isLoading = true);

      try {
        var request = http.MultipartRequest('POST', Uri.parse('${widget.baseUrl}/api/mobile/tickets'));
        
        request.fields['ProblemType'] = problemType;
        request.fields['Description'] = description;
        request.fields['CustomerName'] = customerName;
        request.fields['BillNumber'] = billNumber;
        request.fields['BillDate'] = billDate.toIso8601String();
        request.fields['WarehouseId'] = warehouseId?.toString() ?? '1';
        request.fields['userId'] = widget.userSession.id;

        for (var file in attachedFiles) {
          if (file.path != null) {
            request.files.add(await http.MultipartFile.fromPath('attachments', file.path!));
          }
        }

        var response = await request.send();

        if (response.statusCode == 200) {
          Navigator.pop(context, true); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إنشاء التذكرة')));
        }
      } catch (e) {
        print('Error creating ticket: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تذكرة جديدة')),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'نوع المشكلة', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                onSaved: (v) => problemType = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'الوصف التفصيلي', border: OutlineInputBorder()),
                 maxLines: 3,
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                onSaved: (v) => description = v!,
              ),
               const SizedBox(height: 16),
                 DropdownButtonFormField<int>(
                   value: warehouseId,
                   decoration: const InputDecoration(labelText: 'المستودع', border: OutlineInputBorder()),
                   items: warehouses.map((w) {
                     return DropdownMenuItem<int>(
                       value: w['Id'],
                       alignment: Alignment.centerRight,
                       child: Text(w['Name']),
                     );
                   }).toList(),
                   onChanged: warehouses.isEmpty ? null : (val) => setState(() => warehouseId = val),
                   validator: (v) => v == null ? 'يرجى اختيار المستودع' : null,
                   hint: const Text('جاري تحميل المستودعات...'),
                   disabledHint: const Text('لا توجد مستودعات متاحة'),
                 ),
               const SizedBox(height: 16),
              TextFormField(
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                onSaved: (v) => customerName = v!,
              ),
               const SizedBox(height: 16),
              TextFormField(
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'رقم الفاتورة', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                onSaved: (v) => billNumber = v!,
              ),
               const SizedBox(height: 20),
               Card(
                 elevation: 0,
                 color: Theme.of(context).cardColor,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                 child: ListTile(
                   title: const Text('المرفقات والصور', style: TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Text('تم اختيار ${attachedFiles.length} ملفات'),
                   trailing: IconButton(
                     icon: const Icon(Icons.attach_file, color: Colors.deepOrange),
                     onPressed: pickFiles
                   ),
                 ),
               ),
               const SizedBox(height: 10),
               ...attachedFiles.map((f) => ListTile(
                 leading: const Icon(Icons.file_present, color: Colors.blue),
                 title: Text(f.name, style: const TextStyle(fontSize: 12)),
                 trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18), onPressed: () {
                   setState(() {
                     attachedFiles.remove(f);
                   });
                 }),
               )),
               const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إرسال التذكرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
