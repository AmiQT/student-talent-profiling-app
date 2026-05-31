# 🚀 Gemini AI Integration Setup

## ✅ What You Get

- **100% FREE** agentic AI (1,500 requests/day)
- **Full tool calling support** (database queries via tools)
- **ONE AI model** handles everything (conversations + actions)
- **Fast & reliable** (Google infrastructure)

---

## 📝 Setup Instructions

### 1. Add to `.env` file

Add this line to your `backend/.env` file:

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

### 2. Install Dependencies

```bash
cd backend
pip install google-generativeai>=0.8.0
```

Or install all requirements:

```bash
pip install -r requirements.txt
```

### 3. Restart Backend

```bash
python main.py
```

---

## 🎯 How It Works

```
User Command → Gemini 2.0 Flash (FREE!)
    ↓
Decides: "Need student data"
    ↓
Calls: query_students tool
    ↓
Gets: Real database data
    ↓
Responds: Natural answer with real data ✅
```

**Priority System:**
1. ✅ **Gemini** (if API key available) - FREE + Tools
2. ⚠️ **OpenRouter** (fallback) - If Gemini unavailable
3. 🔧 **Enhanced Supabase** (last resort) - Local queries

---

## 🧪 Test It

```bash
# Test conversation
curl -X POST http://localhost:8000/api/ai/command \
  -H "Content-Type: application/json" \
  -d '{"command": "Hello, apa khabar?"}'

# Test tool calling
curl -X POST http://localhost:8000/api/ai/command \
  -H "Content-Type: application/json" \
  -d '{"command": "Pilih 1 student random"}'
```

**Look for in logs:**
```
🚀 Using Gemini 2.0 Flash (FREE + Tools)
🔧 Gemini requested function: query_students
⚙️ Executing tool: query_students
✅ Got final text response from Gemini
```

---

## 📊 Free Tier Limits

| Feature | Limit |
|---------|-------|
| Requests | 1,500/day |
| Tool Calling | ✅ Unlimited |
| Context Window | 1M tokens |
| Cost | **$0.00** |

---

## ❓ Troubleshooting

### "Gemini API error"
- Check API key is correct
- Ensure `google-generativeai` is installed
- Verify you haven't exceeded 1,500 requests/day

### "Falling back to OpenRouter"
- Gemini API key not found or invalid
- System will automatically use OpenRouter
- Check logs for specific error

### Tool calling not working
- Ensure `AI_GEMINI_ENABLED=true` in .env
- Check logs for tool execution
- Verify database connection is working

---

## 🎊 Success!

Once setup, you have a **fully agentic AI system** with:
- ✅ Natural conversation understanding
- ✅ Real-time database queries via tools
- ✅ Context-aware responses
- ✅ Code-switching (Malay/English)
- ✅ No hallucinations (uses real data!)
- ✅ 100% FREE!

**Enjoy your FREE agentic AI! 🚀**

