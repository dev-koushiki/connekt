const TranslationService = require('../services/translationService');
const { successResponse, errorResponse } = require('../utils/responseHandler');

class TranslateController {
  /**
   * Handle text translation request
   * Body: { text: string, targetLang: string, sourceLang?: string }
   */
  static async translate(req, res) {
    try {
      const { text, targetLang, sourceLang = 'auto' } = req.body;

      if (!text || typeof text !== 'string') {
        return errorResponse(res, 400, 'Text to translate is required.');
      }

      if (!targetLang || typeof targetLang !== 'string') {
        return errorResponse(res, 400, 'Target language code is required.');
      }

      const result = await TranslationService.translateText(
        text,
        targetLang.trim().toLowerCase(),
        sourceLang ? sourceLang.trim().toLowerCase() : 'auto'
      );

      return successResponse(res, 200, 'Text translated successfully.', result);
    } catch (err) {
      console.error('[Translate Controller Error]:', err);
      return errorResponse(res, 500, 'Dynamic translation failed.');
    }
  }
}

module.exports = TranslateController;
