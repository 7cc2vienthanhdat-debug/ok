export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // ============================================================
    // 1. NHẬN THÔNG TIN THIẾT BỊ TỪ FILE .DYLIB KHI MỞ GAME
    // ============================================================
    if (request.method === "POST") {
      try {
        const body = await request.json();
        if (body.action === "log") {
          const deviceId = (body.device_id || "Unknown").substring(0, 8);
          const modelName = body.model || "iPhone";
          const iosVer = body.ios || "iOS";

          const now = new Date();
          const timeStr = now.toLocaleString("vi-VN", {
            timeZone: "Asia/Ho_Chi_Minh",
            hour12: false
          });

          if (env.DEVICES_KV) {
            let list = await env.DEVICES_KV.get("devices_list", { type: "json" }) || [];
            
            // Xóa dòng cũ nếu máy này đã từng mở game
            list = list.filter(item => item.id !== deviceId);

            // Đưa thông tin lần mở mới nhất lên đầu
            list.unshift({
              id: deviceId,
              model: modelName,
              ios: iosVer,
              last_seen: timeStr
            });

            await env.DEVICES_KV.put("devices_list", JSON.stringify(list.slice(0, 100)));
          }

          return new Response(JSON.stringify({ status: "success" }), {
            headers: corsHeaders,
            status: 200
          });
        }
      } catch (err) {
        return new Response(JSON.stringify({ status: "error", message: err.message }), {
          headers: corsHeaders,
          status: 400
        });
      }
    }

    // ============================================================
    // 2. TRẢ DANH SÁCH THIẾT BỊ CHO ADMIN PANEL
    // ============================================================
    let devicesData = [];
    if (env.DEVICES_KV) {
      devicesData = await env.DEVICES_KV.get("devices_list", { type: "json" }) || [];
    }

    return new Response(JSON.stringify({
      status: "success",
      data: devicesData
    }), {
      headers: corsHeaders,
      status: 200
    });
  }
};
