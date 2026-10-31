import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← telefonga saqlash uchun
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'dart:convert'; // ← ro'yxatni matnga aylantirish uchun (jsonEncode, jsonDecode)
import 'package:flutter/services.dart';

// ↓↓↓ YANGI FUNKSIYA SHU YERGA, classlardan TASHQARIDA ↓↓↓
// Ismga qarab rang tanlaydi. Bir xil ism doim bir xil rang oladi
Color avatarColor(String name) {
  // Colors.primaries: tayyor ranglar ro'yxati (qizil, ko'k, yashil...)
  // name.length % ro'yxat uzunligi: ism uzunligidan ro'yxat ichidagi o'rin chiqaradi
  return Colors.primaries[name.length % Colors.primaries.length];
}
// ↑↑↑ funksiya shu yerda tugadi ↑↑↑

class ContactPage extends StatefulWidget {
  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<Map<String, String>> contacts = [
    {"Name": "Anvar", "Number": "+998901234567"},
  ];
  final nameController =
      TextEditingController(); // ism yozilgan matnni ushlaydi
  final numberController =
      TextEditingController(); // raqam yozilgan matnni ushlaydi
  String query = "";
  final searchFocus = FocusNode(); // ← qidiruv maydonining fokusini boshqaradi // qidiruvga yozilgan matn shu yerda turadi. Boshida bo'sh
  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final text = jsonEncode(contacts);
    await prefs.setString("contacts", text);
  }

  Future<void> loadContacts() async {
    final prefs =
        await SharedPreferences.getInstance(); // telefon xotirasini ochadi
    final text = prefs.getString(
      'contacts',
    ); // ← saveContacts dagi setString ning birinchi qiymati bilan BIR XIL nom
    if (text != null) {
      // null = hali hech narsa saqlanmagan
      final list = jsonDecode(text) as List; // matn → ro'yxat
      setState(() {
        // ekranni yangilaydi
        contacts = list
            .map((e) => Map<String, String>.from(e))
            .where((c) => c["Name"]!.trim().isNotEmpty)
            .toList();
      });
    }
  }

  @override
  void initState() {
    // sahifa yaratilganda BIR MARTA ishlaydi
    super.initState(); // majburiy, birinchi qator
    loadContacts(); // ilova ochilishi bilan saqlanganini o'qiydi
  }

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = contacts.where((c) {
      return c["Name"]!.toLowerCase().contains(query.toLowerCase()) ||
          c["Number"]!.contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text("Contacts", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              focusNode: searchFocus,
              decoration: InputDecoration(
                hintText: "Search",
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  query = value; //yozilgan matnni saqlaydi
                });
              },
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      "Kontakt topilmadi",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior
                        .onDrag, // ← YANGI: surganda klaviatura yopiladi
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final realIndex = contacts.indexOf(contact);
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: avatarColor(contact["Name"]!),
                            foregroundColor: Colors.white,
                            child: Text(contact["Name"]![0]),
                          ),
                          title: Text(
                            contact["Name"]!, // ism
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ), // qalin
                          ),
                          subtitle: Text(contact["Number"]!), // raqam
                          onTap: () async {
                            searchFocus.canRequestFocus = false; // ← YANGI: maydon fokus olishini vaqtincha taqiqlaydi
                            searchFocus.unfocus(); // ← fokusni olib tashlaydi (avvalgi FocusScope qatori o'rniga)

                            // kontaktga bosilganda
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ContactDetailsPage(contact: contact),
                              ),
                            );
                            Future.delayed(Duration(milliseconds: 300), () {
                              searchFocus.canRequestFocus = true; // ← maydon yana oddiy ishlaydi (bosganda yoziladi)
                            });
                            if (result == "delete") {
                              // sahifadan "delete" xabari kelsa
                              setState(() {
                                contacts.removeAt(
                                  realIndex,
                                ); // shu kontaktni o'chiradi
                              });
                              saveContacts(); // telefonga saqlaydi
                            } else if (result != null) {
                              // aks holda bu edit natijasi (Map)
                              setState(() {
                                contacts[realIndex] = result; // eski kontaktni yangisi bilan almashtiradi
                              });
                              saveContacts();
                            }
                          },
                          onLongPress: () {
                            // uzoq bosilganda
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.delete),
                                    title: Text('Delete'),
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text("Are you sure ?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(
                                                  context,
                                                ); // "No": faqat oynani yopadi
                                              },
                                              child: Text("No"),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  contacts.removeAt(realIndex);
                                                });
                                                saveContacts(); // setState dan KEYIN
                                                Navigator.pop(
                                                  context,
                                                ); // oynani yopadi
                                                Navigator.pop(
                                                  context,
                                                ); // panelni yopadi
                                              },
                                              child: Text("Yes"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.share),
                                    title: Text('Share'),
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(hintText: "Name"),
                  ),
                  TextField(
                    controller: numberController,
                    decoration: InputDecoration(hintText: "Number"),

                    keyboardType: TextInputType.phone, // ← shu qatorni qo'sh. phone = raqam klaviaturasi
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isNotEmpty &&
                          numberController.text.trim().isNotEmpty) {
                        // faqat shunda qo'sh

                        setState(() {
                          contacts.add({
                            "Name": nameController.text.trim(),
                            "Number": numberController.text.trim(),
                          });
                        });
                        saveContacts(); // ← YANGI, setState dan KEYIN
                        nameController.clear();
                        numberController.clear();
                        Navigator.pop(
                          context,
                        ); // faqat muvaffaqiyatli bo'lsa yopiladi
                      } else {
                        // ← ism yoki raqam bo'sh bo'lsa shu yer ishlaydi
                        // SnackBar ni ko'rsatish uchun ScaffoldMessenger kerak.
                        // U Scaffold ga "pastda xabar chiqar" deb buyuradi
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Add name and number"), // ← shu yerga xabar yoz, masalan "Ism va raqamni kiriting"
                          ),
                        );
                      } //shuyerda tugydi
                    },
                    child: Text("Add Contact"),
                  ),
                ],
              ),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class ContactDetailsPage extends StatelessWidget {
  final Map<String, String> contact;
  ContactDetailsPage({required this.contact});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(contact["Name"]!),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // TextEditingController(text: ...) — maydon ochilganda ichida shu matn turadi
              final nameC = TextEditingController(
                text: contact["Name"],
              ); // ← eski ism
              final numberC = TextEditingController(text: contact["Number"]);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameC,
                        decoration: InputDecoration(hintText: "Name"),
                      ),
                      TextField(
                        // ← raqam uchun (QO'SH)
                        controller: numberC,
                        decoration: InputDecoration(hintText: "Number"),
                        keyboardType: TextInputType.phone, // ← shu qatorni qo'sh. phone = raqam klaviaturasi
                      ),
                      ElevatedButton(
                        // ← saqlash tugmasi (QO'SH)
                        onPressed: () {
                          if (nameC.text.trim().isEmpty ||
                              numberC.text.trim().isEmpty) {
                            return; // bo'sh bo'lsa hech narsa qilmaydi
                          }
                          Navigator.pop(context); // dialogni yop
                          Navigator.pop(context, {
                            // sahifani yop + natija yuvor
                            "Name": nameC.text.trim(),
                            "Number": numberC.text.trim(),
                          });
                        },
                        child: Text("Save"),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete), // ← chiqindi ikonkasi
            onPressed: () {
              showDialog(
                // ← "Are you sure?" oynasi
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Are you sure?"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // ← "No": faqat oynani yopadi
                      },
                      child: Text("No"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, "delete");
                      },
                      child: Text("Yes"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: avatarColor(contact["Name"]!),
              foregroundColor: Colors.white,
              child: Text(contact["Name"]![0], style: TextStyle(fontSize: 40)),
            ),
            SizedBox(height: 16),
            Text(
              contact["Name"]!, // ← faqat ism, "Name:" yozuvisiz
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24), // ← ism bilan raqam kartasi orasidagi masofa
            Card(
              // ← raqam uchun kartochka
              child: ListTile(
                leading: Icon(Icons.phone),
                title: Text(contact["Number"]!),
                trailing:IconButton(
                icon:Icon(Icons.copy),
                onPressed: () {
                Clipboard.setData(ClipboardData(text:contact["Number"]!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content:Text("Number copied")),
                );
  },
  ),
                onTap: () async {
                  await FlutterPhoneDirectCaller.callNumber(contact["Number"]!);
},
              ),
        ),
        ],
      ),
    ),
    );
  }
}

void main() {
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: ContactPage()));
}
